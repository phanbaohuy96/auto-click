package com.pbh.autoclick.overlay

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.display.DisplayManager
import android.os.IBinder
import android.util.Log
import android.view.Display
import android.view.ViewConfiguration
import android.view.WindowManager
import com.pbh.autoclick.domain.editor.StepDraft
import com.pbh.autoclick.domain.editor.newStep
import com.pbh.autoclick.domain.editor.previewing
import com.pbh.autoclick.domain.editor.toDraft
import com.pbh.autoclick.domain.editor.toStep
import com.pbh.autoclick.domain.editor.withPointsFrom
import com.pbh.autoclick.domain.editor.withStepAdded
import com.pbh.autoclick.domain.editor.withStepMoved
import com.pbh.autoclick.domain.editor.withStepRemoved
import com.pbh.autoclick.domain.editor.withStepReplaced
import com.pbh.autoclick.domain.editor.withStepsAdded
import com.pbh.autoclick.domain.model.AppResult
import com.pbh.autoclick.domain.overlay.Marker
import com.pbh.autoclick.domain.overlay.withMarkerMoved
import com.pbh.autoclick.domain.recording.toSteps
import com.pbh.autoclick.domain.repository.ScenarioRepository
import com.pbh.autoclick.domain.run.FinishReason
import com.pbh.autoclick.domain.run.RunEvent
import com.pbh.autoclick.domain.run.ScenarioRunner
import com.pbh.autoclick.domain.run.freeTheTouchGesture
import com.pbh.autoclick.domain.scenario.GestureLimits
import com.pbh.autoclick.domain.scenario.Scenario
import com.pbh.autoclick.domain.scenario.ScreenPoint
import com.pbh.autoclick.domain.settings.ControlPosition
import com.pbh.autoclick.domain.settings.SettingsRepository
import com.pbh.autoclick.overlay.ui.RecordingEvent
import com.pbh.autoclick.service.AutoClickAccessibilityService
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

/**
 * Where a run lives (GX-7), and what holds the Overlay windows open.
 *
 * A foreground service for two reasons, only one of which is the system's: it keeps the process
 * alive while another application is in front, and it puts the run behind a notification the user
 * cannot miss. Something driving the phone by itself should never be invisible.
 */
@AndroidEntryPoint
class OverlayService : Service() {
    @Inject
    lateinit var scenarios: ScenarioRepository

    @Inject
    lateinit var settings: SettingsRepository

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    /**
     * The Context every Overlay window and every screen measurement goes through.
     *
     * A window context rather than the Service's own, and not as a formality: a Service Context is
     * not associated with a display, so `Context.display` throws on it and
     * [currentScreenProfile] with it. It is also what `TYPE_APPLICATION_OVERLAY` has wanted since
     * API 30 — the same fix answers both.
     *
     * Built from an explicit [Display], because the two-argument `createWindowContext` needs a
     * display-associated Context to begin with and a Service has none. Naming the display is the
     * only way in from here.
     */
    private lateinit var overlayContext: Context
    private var coordinator: OverlayCoordinator? = null
    private var runner: ScenarioRunner? = null
    private var runJob: Job? = null
    private var recorder: Recorder? = null

    /** RD-5: true while a recorded touch is being handed back, so nothing records the handing. */
    private var replaying = false
    private var scenario: Scenario? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createRunNotificationChannel()
        val display = getSystemService(DisplayManager::class.java).getDisplay(Display.DEFAULT_DISPLAY)
        overlayContext = createWindowContext(display, WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, null)
        val active =
            OverlayCoordinator(
                context = overlayContext,
                windowManager = overlayContext.getSystemService(WindowManager::class.java),
                callbacks = callbacks,
            )
        coordinator = active
        // OV-29: the notification is re-posted whenever what it would say changes, and never
        // otherwise — a notification rebuilt on every countdown tick flickers and loses its place.
        active.state
            .map { it.notification() }
            .distinctUntilChanged()
            .onEach { updateRunNotification(it) }
            .launchIn(scope)
        scope.launch {
            active.placeControl(
                settings.settings
                    .first()
                    .controlPosition
                    ?.toPoint(),
            )
        }
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        startForeground(
            NOTIFICATION_ID,
            buildRunNotification(coordinator?.state?.value?.notification() ?: RunNotificationState()),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
        )

        when (intent?.action) {
            ACTION_OPEN -> intent.scenarioId()?.let(::open)
            ACTION_STOP -> callbacks.onStop()
            ACTION_FREE_TOUCH -> callbacks.onFreeTheTouch()
            ACTION_CLOSE -> stopSelf()
            else -> Unit
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        runner?.requestStop()
        coordinator?.hide()
        coordinator = null
        scope.cancel()
        super.onDestroy()
    }

    private fun open(id: UUID) {
        scope.launch {
            when (val loaded = scenarios.load(id)) {
                is AppResult.Success -> {
                    scenario = loaded.data.scenario
                    coordinator?.show(loaded.data.scenario)
                }

                is AppResult.Failure -> {
                    Log.w(TAG, "could not open scenario $id: ${loaded.error}")
                    stopSelf()
                }
            }
        }
    }

    /** GX-7, GX-8, GX-11: starting a run, ending one, and the recovery that is neither. */
    private val runCallbacks =
        object : RunCallbacks {
            override fun onStart() {
                val current = scenario ?: return
                // One run at a time. Start is only offered while stopped, but the state and the
                // job are two facts and a second runner would dispatch into the first one's
                // strokes — the job is the one that knows.
                if (runJob?.isActive == true) return
                // OV-20: belt as well as braces. OverlayUiState.showPanel already refuses to draw
                // the panel once a run exists; closing it here means the focusable window is gone
                // before the first Gesture rather than one state update later.
                coordinator?.update { copy(panel = null) }
                val dispatcher = accessibilityDispatcher() ?: return
                val activeRunner = ScenarioRunner(dispatcher, dispatcher.gestureLimits)
                runner = activeRunner
                runJob =
                    scope.launch {
                        try {
                            activeRunner.run(current, overlayContext.currentScreenProfile()) { event ->
                                coordinator?.update { applied(event, current.steps.size) }
                            }
                        } finally {
                            // OV-25: the run is over however it ended, and nothing else will say
                            // so. A cancelled coroutine sends no Finished event, and the Overlay
                            // would keep the state only a live runner can leave.
                            runner = null
                            coordinator?.update { settled() }
                        }
                    }
            }

            /**
             * OV-25: Stop is pressed when there is nothing to stop, and that is ordinary use.
             *
             * The notification offers Stop whenever a run is possible, and the tile and the
             * control are reachable long before one and long after. [OverlayUiState.stopping]
             * refuses the transition rather than the press: `Stopping` ends only when a runner
             * reports back, so entering it without one strands the Overlay there — no Markers, no
             * panel, and a Stop button wired to nothing.
             */
            override fun onStop() {
                runner?.requestStop()
                coordinator?.update { stopping() }
            }

            /**
             * GX-11, first half: a single one-millisecond tap, which is cheap and usually enough.
             *
             * The corner is the least likely place on a screen to carry a control, and the point
             * of the tap is not where it lands but that a complete down-and-up reaches the system.
             * Whether this clears a latched touch is **unverified on hardware** — see
             * android/docs/testing.md. The second half, cycling the service, is the user's to do
             * from the Settings screen onboarding sends them to.
             */
            override fun onFreeTheTouch() {
                val dispatcher = accessibilityDispatcher() ?: return
                scope.launch {
                    dispatcher.releaseEverything()
                    dispatcher.dispatch(freeTheTouchGesture(ScreenPoint(0, 0)))
                }
            }
        }

    /**
     * RD-1 to RD-8: a session of real touches, handed on to the application underneath as it goes.
     *
     * Recording is not a run and does not go through [ScenarioRunner]: nothing here is being
     * replayed from a **Scenario**, it is being written into one. What the two share is that both
     * take the editor off the screen, because a **Marker** left attached would swallow the very
     * touches being recorded.
     */
    private val recordCallbacks =
        object : RecordCallbacks {
            override fun onRecord() {
                if (scenario == null) return
                val dispatcher = accessibilityDispatcher() ?: return
                replaying = false
                coordinator?.update { copy(panel = null, recording = RecordingSession()) }
                recorder =
                    Recorder(dispatcher) { touch ->
                        coordinator?.update {
                            copy(recording = recording?.copy(touches = recording.touches + 1))
                        }
                        Log.d(TAG, "recorded a touch of ${touch.durationMilliseconds}ms")
                    }
            }

            /**
             * RD-3, RD-8: the session becomes Steps and is added to the Scenario.
             *
             * `scaledTouchSlop` decides which of them are taps. It is the platform's own idea of
             * how far a finger may wander while still meaning to stay still, and using anything
             * else would disagree with every other app on the phone.
             */
            override fun onStopRecording() {
                val current = scenario ?: return
                val captured = recorder?.touches.orEmpty().toList()
                recorder = null
                replaying = false
                coordinator?.update { copy(recording = null) }
                if (captured.isEmpty()) return

                val limits = AutoClickAccessibilityService.instance?.gestureLimits ?: GestureLimits()
                val slop = ViewConfiguration.get(overlayContext).scaledTouchSlop
                val profile = current.screenProfile ?: overlayContext.currentScreenProfile()
                applyEdit(current.withStepsAdded(captured.toSteps(limits, slop), profile))
            }

            /**
             * RD-5: the touch is recorded, then handed to whatever is underneath.
             *
             * A dispatched **Gesture** is delivered to the topmost window that accepts touches,
             * and while recording that window is the recording layer — so without care the layer
             * records its own re-emission, and one tap becomes two Steps. It did, on the first
             * run: one tap, `recorded a touch of 0ms` and `recorded a touch of 1ms`, 41ms apart.
             *
             * Two guards, because one was not enough. The layer's touchable flag goes away for the
             * length of the re-emission, which is what lets the touch reach the application at
             * all; and [replaying] refuses events outright, because `updateViewLayout` is not
             * applied the instant it is called and the gap is exactly long enough for a synthetic
             * tap to slip through it.
             *
             * The cost is written down rather than hidden: a real touch arriving inside that
             * window reaches the application and is **not recorded**. For a tap it is a few tens
             * of milliseconds.
             */
            override fun onRecordingEvent(event: RecordingEvent) {
                if (replaying) return
                val active = recorder ?: return
                val gesture = active.accept(event) ?: return
                replaying = true
                scope.launch {
                    try {
                        coordinator?.update { copy(recording = recording?.copy(listening = false)) }
                        delay(FLAG_SETTLE_MILLISECONDS)
                        active.replay(gesture)
                        // A second wait, so a trailing synthetic event is still refused.
                        delay(FLAG_SETTLE_MILLISECONDS)
                    } finally {
                        replaying = false
                        coordinator?.update { copy(recording = recording?.copy(listening = true)) }
                    }
                }
            }
        }

    /** FS-15: every one of these is written to disk as it happens. There is no Save. */
    private val editCallbacks =
        object : EditCallbacks {
            /**
             * A new Step in the middle of the screen, then the panel open on it (`OV-23`).
             *
             * The middle because it is the one place guaranteed to be visible and not under the
             * floating control, and because the Marker is meant to be dragged from there to
             * wherever it belongs — it is a starting position, not a guess at the user's intent.
             */
            override fun onAddStep() {
                val current = scenario ?: return
                val profile = current.screenProfile ?: overlayContext.currentScreenProfile()
                val added = newStep(ScreenPoint(profile.widthPixels / 2, profile.heightPixels / 2))
                applyEdit(current.withStepAdded(added, profile))
                openPanel(added.id)
            }

            /**
             * OV-21: while the panel is open, a drag edits the **draft**, like everything else in
             * it. Closed, it edits the Scenario and is saved at once, as dragging always has.
             *
             * One rule, and the reason for it is that the other way loses work: the draft is
             * written over the Step on Save, so a drag that went straight to disk would be
             * silently undone by a Save the user thought was unrelated.
             */
            override fun onMarkerMoved(
                marker: Marker,
                to: ScreenPoint,
            ) {
                val current = scenario ?: return
                val draft =
                    coordinator
                        ?.state
                        ?.value
                        ?.editing
                        ?.draft
                if (draft == null || draft.stepId != marker.stepId) {
                    applyEdit(current.withMarkerMoved(marker, to))
                    return
                }
                val movedStep =
                    current
                        .previewing(draft.toStep())
                        .withMarkerMoved(marker, to)
                        .steps
                        .firstOrNull { it.id == draft.stepId } ?: return
                coordinator?.update {
                    withStep { open -> open.copy(step = open.step.copy(draft = draft.withPointsFrom(movedStep))) }
                }
            }

            /** OV-7: a Marker is placed by dragging and configured by tapping. This is the tap. */
            override fun onMarkerTapped(marker: Marker) {
                openPanel(marker.stepId)
            }

            override fun onStepOpened(stepId: UUID) {
                openPanel(stepId)
            }

            override fun onStepSaved(draft: StepDraft) {
                val current = scenario ?: return
                val profile = current.screenProfile ?: overlayContext.currentScreenProfile()
                applyEdit(current.withStepReplaced(draft.toStep(), profile))
                coordinator?.update { copy(panel = null) }
            }

            override fun onStepDeleted(stepId: UUID) {
                val current = scenario ?: return
                applyEdit(current.withStepRemoved(stepId))
                // The Scenario panel stays open: deleting from the list is one of several things
                // being done there. The Step panel cannot, because its subject is gone.
                coordinator?.update { copy(panel = if (editing?.draft?.stepId == stepId) null else panel) }
            }

            /**
             * OV-6: the order changes at once, and the open panel renumbers with it.
             *
             * The draft is carried over rather than rebuilt from disk. Moving a Step changes where
             * it sits, not what it does, and losing half-finished edits for pressing an arrow
             * would be a punishment for using the button.
             */
            override fun onStepMoved(
                stepId: UUID,
                by: Int,
            ) {
                val current = scenario ?: return
                val moved = current.withStepMoved(stepId, by)
                applyEdit(moved)
                val index = moved.steps.indexOfFirst { it.id == stepId }
                coordinator?.update {
                    withStep { open ->
                        open.copy(step = open.step.copy(stepNumber = index + 1, stepCount = moved.steps.size))
                    }
                }
            }

            /**
             * OV-24: how a Step that draws no Marker (`SM-8`) is reached from its neighbours.
             *
             * The panel refuses to walk away from unsaved edits, so nothing is discarded here —
             * [EditingStep.canGoBack] has already said no.
             */
            override fun onStepNavigated(
                stepId: UUID,
                by: Int,
            ) {
                val current = scenario ?: return
                val index = current.steps.indexOfFirst { it.id == stepId }
                current.steps.getOrNull(index + by)?.let { openPanel(it.id) }
            }

            /** OV-28: the Scenario's own fields — its name, how often it runs, its countdown. */
            override fun onScenarioChanged(scenario: Scenario) {
                applyEdit(scenario)
            }
        }

    /** OV-14, OV-30: the Overlay as a thing on the screen rather than as an editor. */
    private val shellCallbacks =
        object : ShellCallbacks {
            override fun onControlMoved(at: ScreenPoint) {
                scope.launch { settings.setControlPosition(ControlPosition(at.x, at.y)) }
            }

            /** OV-30: the Overlay is not the only place Auto Click lives, and it says so. */
            override fun onOpenApp() {
                packageManager.getLaunchIntentForPackage(packageName)?.let {
                    startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                }
            }

            override fun onCloseOverlay() {
                stopSelf()
            }
        }

    /**
     * The three handed to the Overlay as one.
     *
     * Delegation rather than one object with fifteen methods in it. They answer to three different
     * parts of the specification and change for three different reasons, and a single list of
     * fifteen was how the last one stopped being readable.
     */
    private val callbacks =
        object :
            OverlayCallbacks,
            RunCallbacks by runCallbacks,
            RecordCallbacks by recordCallbacks,
            EditCallbacks by editCallbacks,
            ShellCallbacks by shellCallbacks {}

    /** FS-15: there is no Save button for the Scenario itself — editing it *is* saving it. */
    private fun applyEdit(edited: Scenario) {
        scenario = edited
        coordinator?.show(edited)
        scope.launch { scenarios.save(edited) }
    }

    /**
     * Opens the panel on one Step (`OV-21`).
     *
     * [GestureLimits] come from the connected service rather than from the defaults, because
     * `SM-17` judges a Step against **this** device: a panel using the defaults would let a Step
     * through on a phone whose limits are lower, and that Step would silently do nothing.
     */
    private fun openPanel(stepId: UUID) {
        val current = scenario ?: return
        val index = current.steps.indexOfFirst { it.id == stepId }
        if (index < 0) return
        val limits = AutoClickAccessibilityService.instance?.gestureLimits ?: GestureLimits()
        coordinator?.update {
            copy(
                panel =
                    PanelState.StepEditor(
                        EditingStep(
                            draft = current.steps[index].toDraft(current.screenProfile),
                            original = current.steps[index],
                            stepNumber = index + 1,
                            stepCount = current.steps.size,
                            limits = limits,
                            profile = current.screenProfile,
                        ),
                    ),
            )
        }
    }

    private fun accessibilityDispatcher(): AutoClickAccessibilityService? =
        AutoClickAccessibilityService.instance
            ?: null.also { Log.w(TAG, "no accessibility service connected") }

    private fun Intent.scenarioId(): UUID? = getStringExtra(EXTRA_SCENARIO_ID)?.let { runCatching { UUID.fromString(it) }.getOrNull() }

    companion object {
        private const val TAG = "OverlayService"
        internal const val NOTIFICATION_ID = 1

        /** RD-5: long enough for `updateViewLayout` to have taken the touchable flag away. */
        private const val FLAG_SETTLE_MILLISECONDS = 24L

        const val ACTION_OPEN = "com.pbh.autoclick.OPEN"
        const val ACTION_STOP = "com.pbh.autoclick.STOP"
        const val ACTION_FREE_TOUCH = "com.pbh.autoclick.FREE_TOUCH"
        const val ACTION_CLOSE = "com.pbh.autoclick.CLOSE"
        const val EXTRA_SCENARIO_ID = "scenarioId"

        fun open(
            context: Context,
            scenarioId: UUID,
        ) {
            context.startForegroundService(
                Intent(context, OverlayService::class.java)
                    .setAction(ACTION_OPEN)
                    .putExtra(EXTRA_SCENARIO_ID, scenarioId.toString()),
            )
        }
    }
}

private fun ControlPosition.toPoint(): ScreenPoint = ScreenPoint(x, y)

/** Turns a runner event into the shape the Overlay wears (OV-16, OV-17). */
internal fun OverlayUiState.applied(
    event: RunEvent,
    stepCount: Int,
): OverlayUiState =
    when (event) {
        is RunEvent.CountingDown ->
            copy(
                run = OverlayUiState.RunState.CountingDown(event.remainingMilliseconds),
                lastFinish = null,
            )

        is RunEvent.StepStarted ->
            copy(run = OverlayUiState.RunState.Running(event.stepIndex + 1, stepCount))

        RunEvent.Stopping -> copy(run = OverlayUiState.RunState.Stopping)

        is RunEvent.Finished ->
            copy(
                run = OverlayUiState.RunState.Stopped,
                // OV-17: finishing normally is not news; every other reason is.
                lastFinish = event.reason.takeIf { it != FinishReason.Completed },
            )
    }

/**
 * OV-25: Stop asked for while a run is in flight. Asked for at any other moment, nothing moves.
 *
 * `Stopping` is the one state the Overlay cannot leave by itself — it ends when the runner reports
 * `Finished`, and a Stop pressed with no runner behind it would wait for a report that never
 * comes. The cost of getting this wrong is not cosmetic: `showMarkers` and `showPanel` are both
 * "nothing is running", so a stranded `Stopping` takes the whole editor with it.
 */
internal fun OverlayUiState.stopping(): OverlayUiState =
    if (run is OverlayUiState.RunState.Stopped) this else copy(run = OverlayUiState.RunState.Stopping)

/**
 * OV-25: the run is over, however it ended.
 *
 * Belt to [applied]'s braces. `RunEvent.Finished` covers every ending the runner knows about, and
 * a cancelled coroutine is the one it does not: the `finally` inside it still terminates the
 * strokes (`GX-9`), but nobody is left to say so to the interface.
 */
internal fun OverlayUiState.settled(): OverlayUiState =
    if (run is OverlayUiState.RunState.Stopped) this else copy(run = OverlayUiState.RunState.Stopped)

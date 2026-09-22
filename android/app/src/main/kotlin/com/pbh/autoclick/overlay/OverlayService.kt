package com.pbh.autoclick.overlay

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.display.DisplayManager
import android.os.IBinder
import android.util.Log
import android.view.Display
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
import com.pbh.autoclick.domain.model.AppResult
import com.pbh.autoclick.domain.overlay.Marker
import com.pbh.autoclick.domain.overlay.withMarkerMoved
import com.pbh.autoclick.domain.repository.ScenarioRepository
import com.pbh.autoclick.domain.run.FinishReason
import com.pbh.autoclick.domain.run.GestureDispatcher
import com.pbh.autoclick.domain.run.RunEvent
import com.pbh.autoclick.domain.run.ScenarioRunner
import com.pbh.autoclick.domain.run.freeTheTouchGesture
import com.pbh.autoclick.domain.scenario.GestureLimits
import com.pbh.autoclick.domain.scenario.Scenario
import com.pbh.autoclick.domain.scenario.ScreenPoint
import com.pbh.autoclick.service.AutoClickAccessibilityService
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
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
    private var scenario: Scenario? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createRunNotificationChannel()
        val display = getSystemService(DisplayManager::class.java).getDisplay(Display.DEFAULT_DISPLAY)
        overlayContext = createWindowContext(display, WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, null)
        coordinator =
            OverlayCoordinator(
                context = overlayContext,
                windowManager = overlayContext.getSystemService(WindowManager::class.java),
                callbacks = callbacks,
            )
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        startForeground(
            NOTIFICATION_ID,
            buildRunNotification(),
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

    private val callbacks =
        object : OverlayCoordinator.Callbacks {
            override fun onStart() {
                val current = scenario ?: return
                // OV-20: belt as well as braces. OverlayUiState.showStepPanel already refuses to
                // draw the panel once a run exists; closing it here means the focusable window is
                // gone before the first Gesture rather than one state update later.
                coordinator?.update { copy(editing = null) }
                val dispatcher = accessibilityDispatcher() ?: return
                val activeRunner = ScenarioRunner(dispatcher, dispatcher.gestureLimits)
                runner = activeRunner
                runJob =
                    scope.launch {
                        activeRunner.run(current, overlayContext.currentScreenProfile()) { event ->
                            coordinator?.update { applied(event, current.steps.size) }
                        }
                    }
            }

            override fun onStop() {
                runner?.requestStop()
                coordinator?.update { copy(run = OverlayUiState.RunState.Stopping) }
            }

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
             * GX-11, first half: a single one-millisecond tap, which is cheap and usually enough.
             *
             * The corner is the least likely place on a screen to carry a control, and the point
             * of the tap is not where it lands but that a complete down-and-up reaches the system.
             * Whether this clears a latched touch is **unverified on hardware** — see
             * android/docs/testing.md. The second half, cycling the service, is offered by the
             * onboarding screen, which is not built yet.
             */
            override fun onFreeTheTouch() {
                val dispatcher = accessibilityDispatcher() ?: return
                scope.launch {
                    dispatcher.releaseEverything()
                    dispatcher.dispatch(freeTheTouchGesture(ScreenPoint(0, 0)))
                }
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
                if (draft != null && draft.stepId == marker.stepId) {
                    val movedStep =
                        current
                            .previewing(draft.toStep())
                            .withMarkerMoved(marker, to)
                            .steps
                            .firstOrNull { it.id == draft.stepId } ?: return
                    coordinator?.update {
                        copy(editing = editing?.copy(draft = draft.withPointsFrom(movedStep)))
                    }
                } else {
                    applyEdit(current.withMarkerMoved(marker, to))
                }
            }

            /** OV-7: a Marker is placed by dragging and configured by tapping. This is the tap. */
            override fun onMarkerTapped(marker: Marker) {
                openPanel(marker.stepId)
            }

            override fun onStepSaved(draft: StepDraft) {
                val current = scenario ?: return
                applyEdit(current.withStepReplaced(draft.toStep(), current.screenProfile ?: overlayContext.currentScreenProfile()))
                coordinator?.update { copy(editing = null) }
            }

            override fun onStepDeleted(stepId: UUID) {
                val current = scenario ?: return
                applyEdit(current.withStepRemoved(stepId))
                coordinator?.update { copy(editing = null) }
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
                    copy(editing = editing?.copy(stepNumber = index + 1, stepCount = moved.steps.size))
                }
            }

            /**
             * OV-24: the only route to a Step that draws no Marker (`SM-8`).
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
        }

    /** FS-15: there is no Save button for the Scenario itself — editing it *is* saving it. */
    private fun applyEdit(edited: Scenario) {
        scenario = edited
        coordinator?.show(edited)
        scope.launch { scenarios.save(edited) }
    }

    /**
     * Opens the Step panel on one Step (`OV-21`).
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
                editing =
                    EditingStep(
                        draft = current.steps[index].toDraft(current.screenProfile),
                        original = current.steps[index],
                        stepNumber = index + 1,
                        stepCount = current.steps.size,
                        limits = limits,
                        profile = current.screenProfile,
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

package com.pbh.autoclick.overlay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.IBinder
import android.util.Log
import android.view.WindowManager
import com.pbh.autoclick.R
import com.pbh.autoclick.domain.model.AppResult
import com.pbh.autoclick.domain.overlay.Marker
import com.pbh.autoclick.domain.overlay.withMarkerMoved
import com.pbh.autoclick.domain.repository.ScenarioRepository
import com.pbh.autoclick.domain.run.FinishReason
import com.pbh.autoclick.domain.run.GestureDispatcher
import com.pbh.autoclick.domain.run.RunEvent
import com.pbh.autoclick.domain.run.ScenarioRunner
import com.pbh.autoclick.domain.run.freeTheTouchGesture
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
    private var coordinator: OverlayCoordinator? = null
    private var runner: ScenarioRunner? = null
    private var runJob: Job? = null
    private var scenario: Scenario? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        coordinator =
            OverlayCoordinator(
                context = this,
                windowManager = getSystemService(WindowManager::class.java),
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
            buildNotification(),
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
                val dispatcher = accessibilityDispatcher() ?: return
                val activeRunner = ScenarioRunner(dispatcher, dispatcher.gestureLimits)
                runner = activeRunner
                runJob =
                    scope.launch {
                        activeRunner.run(current, currentScreenProfile()) { event ->
                            coordinator?.update { applied(event, current.steps.size) }
                        }
                    }
            }

            override fun onStop() {
                runner?.requestStop()
                coordinator?.update { copy(run = OverlayUiState.RunState.Stopping) }
            }

            override fun onAddStep() {
                // The Step editor is the next piece of A1; until it exists this does nothing
                // rather than pretending to.
                Log.i(TAG, "add step: not built yet")
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

            override fun onMarkerMoved(
                marker: Marker,
                to: ScreenPoint,
            ) {
                val current = scenario ?: return
                val moved = current.withMarkerMoved(marker, to)
                scenario = moved
                coordinator?.show(moved)
                scope.launch { scenarios.save(moved) }
            }

            override fun onMarkerTapped(marker: Marker) {
                Log.i(TAG, "configure step ${marker.stepNumber}: not built yet")
            }
        }

    private fun accessibilityDispatcher(): AutoClickAccessibilityService? =
        AutoClickAccessibilityService.instance
            ?: null.also { Log.w(TAG, "no accessibility service connected") }

    private fun createNotificationChannel() {
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.run_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification =
        Notification
            .Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.run_notification_title))
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .setOngoing(true)
            // OV-15, GX-12: both actions are here as well as on the control, because a latched
            // touch is exactly the situation in which the control cannot be tapped.
            .addAction(action(ACTION_STOP, R.string.overlay_stop))
            .addAction(action(ACTION_FREE_TOUCH, R.string.overlay_free_the_touch))
            .build()

    private fun action(
        action: String,
        label: Int,
    ): Notification.Action =
        Notification.Action
            .Builder(
                null,
                getString(label),
                PendingIntent.getService(
                    this,
                    action.hashCode(),
                    Intent(this, OverlayService::class.java).setAction(action),
                    PendingIntent.FLAG_IMMUTABLE,
                ),
            ).build()

    private fun Intent.scenarioId(): UUID? = getStringExtra(EXTRA_SCENARIO_ID)?.let { runCatching { UUID.fromString(it) }.getOrNull() }

    companion object {
        private const val TAG = "OverlayService"
        private const val CHANNEL_ID = "auto-click-run"
        private const val NOTIFICATION_ID = 1

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

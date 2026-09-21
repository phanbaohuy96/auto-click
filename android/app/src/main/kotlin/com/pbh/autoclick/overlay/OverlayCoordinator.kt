package com.pbh.autoclick.overlay

import android.content.Context
import android.view.WindowManager
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.pbh.autoclick.core.designsystem.AutoClickTheme
import com.pbh.autoclick.core.overlay.OverlayLayoutParams
import com.pbh.autoclick.core.overlay.OverlayWindow
import com.pbh.autoclick.domain.overlay.Marker
import com.pbh.autoclick.domain.overlay.clampedInto
import com.pbh.autoclick.domain.overlay.markers
import com.pbh.autoclick.domain.scenario.Scenario
import com.pbh.autoclick.domain.scenario.ScreenPoint
import com.pbh.autoclick.overlay.ui.FloatingControl
import com.pbh.autoclick.overlay.ui.FloatingControlActions
import com.pbh.autoclick.overlay.ui.MarkerLayer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Owns the Overlay windows and decides which of them is attached (OV-1, OV-4).
 *
 * Windows are removed rather than hidden, because an Overlay left attached keeps drawing and keeps
 * a `ViewModelStore` alive — [OverlayWindow] clears it on the way out and this class is what calls
 * that.
 */
class OverlayCoordinator(
    private val context: Context,
    windowManager: WindowManager,
    private val callbacks: Callbacks,
) {
    /** What the Overlay asks the service to do. Nothing here decides anything by itself. */
    interface Callbacks {
        fun onStart()

        fun onStop()

        fun onAddStep()

        fun onFreeTheTouch()

        fun onMarkerMoved(
            marker: Marker,
            to: ScreenPoint,
        )

        fun onMarkerTapped(marker: Marker)
    }

    private val control = OverlayWindow(context, windowManager)
    private val markerLayer = OverlayWindow(context, windowManager)

    private val _state = MutableStateFlow(OverlayUiState())
    val state: StateFlow<OverlayUiState> = _state.asStateFlow()

    private var controlPosition = ScreenPoint(0, 0)

    fun update(reduce: OverlayUiState.() -> OverlayUiState) {
        _state.update(reduce)
        refreshWindows()
    }

    fun show(scenario: Scenario) {
        update { copy(scenarioName = scenario.name, markers = scenario.markers()) }
    }

    fun hide() {
        markerLayer.dismiss()
        control.dismiss()
    }

    /** OV-14: the control is dragged anywhere and remembers where it was left. */
    fun moveControl(to: ScreenPoint) {
        controlPosition = to
        control.move(OverlayLayoutParams.floating(x = to.x, y = to.y))
    }

    private fun refreshWindows() {
        val current = _state.value

        if (current.showMarkers && current.markers.isNotEmpty()) {
            markerLayer.show(OverlayLayoutParams.markerLayer(interactive = current.placingMarkers)) {
                AutoClickTheme {
                    val live by state.collectAsStateWithLifecycle()
                    MarkerLayer(
                        markers = live.markers,
                        interactive = live.placingMarkers,
                        onMoved = { marker, point ->
                            callbacks.onMarkerMoved(marker, point.clampedInto(context.currentScreenProfile()))
                        },
                        onTapped = callbacks::onMarkerTapped,
                    )
                }
            }
        } else {
            // OV-11: Markers would be tapped by the very Gestures they describe.
            markerLayer.dismiss()
        }

        control.show(OverlayLayoutParams.floating(x = controlPosition.x, y = controlPosition.y)) {
            AutoClickTheme {
                val live by state.collectAsStateWithLifecycle()
                FloatingControl(
                    state = live,
                    actions =
                        FloatingControlActions(
                            onStart = callbacks::onStart,
                            onStop = callbacks::onStop,
                            onAddStep = callbacks::onAddStep,
                            onTogglePlacing = { update { copy(placingMarkers = !placingMarkers) } },
                            onFreeTheTouch = callbacks::onFreeTheTouch,
                            onToggleCollapsed = { update { copy(collapsed = !collapsed) } },
                        ),
                )
            }
        }
    }
}

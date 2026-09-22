package com.pbh.autoclick.overlay

import android.content.Context
import android.view.WindowManager
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.pbh.autoclick.core.designsystem.OverlayTheme
import com.pbh.autoclick.core.overlay.OverlayLayoutParams
import com.pbh.autoclick.core.overlay.OverlayWindow
import com.pbh.autoclick.domain.editor.previewing
import com.pbh.autoclick.domain.editor.toStep
import com.pbh.autoclick.domain.overlay.markers
import com.pbh.autoclick.domain.scenario.Scenario
import com.pbh.autoclick.domain.scenario.ScreenPoint
import com.pbh.autoclick.overlay.ui.FloatingControl
import com.pbh.autoclick.overlay.ui.FloatingControlActions
import com.pbh.autoclick.overlay.ui.ScenarioPanel
import com.pbh.autoclick.overlay.ui.StepPanel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Owns the Overlay windows and decides which of them are attached (OV-1, OV-4, OV-27).
 *
 * Windows are removed rather than hidden, because an Overlay left attached keeps drawing and keeps
 * a `ViewModelStore` alive — [OverlayWindow] clears it on the way out and this class is what calls
 * that.
 *
 * Placing the control and drawing the Markers are each a job of their own, in
 * [ControlPlacement] and [MarkerWindows]. What is left here is the one question this class exists
 * to answer: given the state, which windows should exist.
 */
class OverlayCoordinator(
    private val context: Context,
    windowManager: WindowManager,
    private val callbacks: OverlayCallbacks,
) {
    private val control = OverlayWindow(context, windowManager)
    private val panel = OverlayWindow(context, windowManager)

    private val _state = MutableStateFlow(OverlayUiState())
    val state: StateFlow<OverlayUiState> = _state.asStateFlow()

    private val placement =
        ControlPlacement(context, control, callbacks::onControlMoved).also {
            // OV-13: the panel and the control both want the bottom of the screen, and the
            // control is the one drawn on top. It moves; the panel does not.
            panel.onResized = { _, height -> it.keepClearOf(height) }
        }
    private val markers =
        MarkerWindows(
            context = context,
            windowManager = windowManager,
            state = state,
            onMoved = callbacks::onMarkerMoved,
            onTapped = callbacks::onMarkerTapped,
        )

    /**
     * The focusable flag last handed to the panel's window (`OV-20`).
     *
     * Kept so the flag is re-applied only when it actually changes. `updateViewLayout` on a window
     * that is gaining or losing focus disturbs the focus inside it, and re-applying the same value
     * on every state change is how that becomes a loop.
     */
    private var panelTyping: Boolean? = null

    /**
     * OV-13: what was attached last time round, so the control can be put back on top.
     *
     * Android stacks windows of one type in the order they were attached, and there is no way to
     * ask for a different one. A Marker handle or the panel attached after the control is
     * therefore drawn **over** it — over Stop, which is the one thing this app promises is always
     * reachable. Re-attaching the control is the only way to take the top back.
     */
    private var attached: String? = null

    fun update(reduce: OverlayUiState.() -> OverlayUiState) {
        _state.update { it.reduce().withMarkers() }
        refreshWindows()
    }

    /** The same thing as [update], in the shape a plain function reference can be passed in. */
    private fun reduce(edit: (OverlayUiState) -> OverlayUiState) = update { edit(this) }

    fun show(scenario: Scenario) {
        update { copy(scenario = scenario, authoringProfile = scenario.screenProfile) }
    }

    /** OV-14: where the control was left last time, or nothing if it has never been moved. */
    fun placeControl(remembered: ScreenPoint?) = placement.place(remembered)

    fun hide() {
        panel.dismiss()
        markers.dismiss()
        control.dismiss()
        _state.value = OverlayUiState()
    }

    /**
     * OV-21: the Markers show the **draft**, not the Step last written to disk.
     *
     * Derived on every update rather than stored, because two copies of the same truth is how a
     * Marker ends up somewhere the Scenario does not agree with. It also answers the thing that
     * looked like a bug on a real device: choosing "swipe" tells the user to drag a destination
     * that, without this, is not drawn until they save.
     */
    private fun OverlayUiState.withMarkers(): OverlayUiState {
        val saved = scenario ?: return copy(markers = emptyList())
        val previewed = editing?.let { saved.previewing(it.draft.toStep()) } ?: saved
        return copy(markers = previewed.markers())
    }

    private fun refreshWindows() {
        val current = _state.value
        markers.refresh(current)
        refreshPanel(current)

        val signature = "${markers.signature}|${panel.isShowing}"
        if (attached != null && attached != signature) control.dismiss()
        attached = signature

        val wasShowing = control.isShowing
        refreshControl()
        if (!wasShowing) placement.settle()
    }

    private fun refreshControl() {
        val at = placement.displayed()
        control.show(OverlayLayoutParams.floating(x = at.x, y = at.y)) {
            OverlayTheme {
                val live by state.collectAsStateWithLifecycle()
                FloatingControl(
                    state = live,
                    actions =
                        FloatingControlActions(
                            onStart = callbacks::onStart,
                            onStop = callbacks::onStop,
                            onAddStep = callbacks::onAddStep,
                            onOpenPanel = { update { copy(panel = PanelState.ScenarioEditor()) } },
                            onFreeTheTouch = callbacks::onFreeTheTouch,
                            onToggleCollapsed = { update { copy(collapsed = !collapsed) } },
                            onDragBy = placement::moveBy,
                            onDragFinished = placement::finishDrag,
                        ),
                )
            }
        }
    }

    /**
     * OV-20, the enforcement half.
     *
     * [OverlayUiState.showPanel] is false whenever anything is running, so the one window allowed
     * to take input focus cannot survive into a run — a `setText` Step never finds this window
     * under `findFocus(FOCUS_INPUT)`. Nothing here has to remember to close it.
     */
    private fun refreshPanel(current: OverlayUiState) {
        if (!current.showPanel) {
            panelTyping = null
            panel.dismiss()
            placement.keepClearOf(0)
            return
        }

        if (panelTyping == current.typing) return
        panelTyping = current.typing

        panel.show(OverlayLayoutParams.panel(typing = current.typing)) {
            OverlayTheme {
                val live by state.collectAsStateWithLifecycle()
                when (val open = live.panel) {
                    is PanelState.StepEditor ->
                        StepPanel(editing = open.step, actions = stepPanelActions(open.step, callbacks, ::reduce))

                    is PanelState.ScenarioEditor ->
                        live.scenario?.let {
                            ScenarioPanel(scenario = it, actions = scenarioPanelActions(it, callbacks, ::reduce))
                        }

                    null -> Unit
                }
            }
        }
    }
}

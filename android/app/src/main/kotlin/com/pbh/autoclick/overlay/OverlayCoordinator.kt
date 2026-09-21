package com.pbh.autoclick.overlay

import android.content.Context
import android.view.WindowManager
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.pbh.autoclick.core.designsystem.AutoClickTheme
import com.pbh.autoclick.core.overlay.OverlayLayoutParams
import com.pbh.autoclick.core.overlay.OverlayWindow
import com.pbh.autoclick.domain.editor.StepDraft
import com.pbh.autoclick.domain.editor.previewing
import com.pbh.autoclick.domain.editor.toStep
import com.pbh.autoclick.domain.overlay.Marker
import com.pbh.autoclick.domain.overlay.clampedInto
import com.pbh.autoclick.domain.overlay.markers
import com.pbh.autoclick.domain.scenario.Scenario
import com.pbh.autoclick.domain.scenario.ScreenPoint
import com.pbh.autoclick.overlay.ui.FloatingControl
import com.pbh.autoclick.overlay.ui.FloatingControlActions
import com.pbh.autoclick.overlay.ui.MarkerLayer
import com.pbh.autoclick.overlay.ui.StepPanel
import com.pbh.autoclick.overlay.ui.StepPanelActions
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import java.util.UUID

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

        /** OV-22: only ever called with a draft that has no violations left. */
        fun onStepSaved(draft: StepDraft)

        fun onStepDeleted(stepId: UUID)

        /** OV-6: renumbers this Marker and its neighbours', and is applied at once. */
        fun onStepMoved(
            stepId: UUID,
            by: Int,
        )

        /** OV-24: opens the panel on the Step [by] places away in the Scenario. */
        fun onStepNavigated(
            stepId: UUID,
            by: Int,
        )
    }

    private val control = OverlayWindow(context, windowManager)
    private val markerLayer = OverlayWindow(context, windowManager)
    private val stepPanel = OverlayWindow(context, windowManager)

    /**
     * The focusable flag last handed to the Step panel's window (`OV-20`).
     *
     * Kept so the flag is re-applied only when it actually changes. `updateViewLayout` on a window
     * that is gaining or losing focus disturbs the focus inside it, and re-applying the same value
     * on every state change is how that becomes a loop.
     */
    private var panelTyping: Boolean? = null

    private val _state = MutableStateFlow(OverlayUiState())
    val state: StateFlow<OverlayUiState> = _state.asStateFlow()

    private var controlPosition = ScreenPoint(0, 0)

    /** The Scenario as last saved. The Markers are derived from it and never stored beside it. */
    private var scenario: Scenario? = null

    fun update(reduce: OverlayUiState.() -> OverlayUiState) {
        _state.update { it.reduce().withMarkers() }
        refreshWindows()
    }

    fun show(scenario: Scenario) {
        this.scenario = scenario
        update { copy(scenarioName = scenario.name, authoringProfile = scenario.screenProfile) }
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

    fun hide() {
        scenario = null
        stepPanel.dismiss()
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
                        editedStepId = live.editedStepId,
                        onMoved = { marker, point ->
                            // OV-10: into the Scenario's own screen, which is what its pixels mean.
                            val into = live.authoringProfile ?: context.currentScreenProfile()
                            callbacks.onMarkerMoved(marker, point.clampedInto(into))
                        },
                        onTapped = callbacks::onMarkerTapped,
                    )
                }
            }
        } else {
            // OV-11: Markers would be tapped by the very Gestures they describe.
            markerLayer.dismiss()
        }

        refreshStepPanel(current)

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

    /**
     * OV-20, the enforcement half.
     *
     * [OverlayUiState.showStepPanel] is false whenever anything is running, so the one window
     * allowed to take input focus cannot survive into a run — a `setText` Step never finds this
     * window under `findFocus(FOCUS_INPUT)`. Nothing here has to remember to close it.
     */
    private fun refreshStepPanel(current: OverlayUiState) {
        if (!current.showStepPanel) {
            panelTyping = null
            stepPanel.dismiss()
            return
        }

        if (panelTyping == current.typing) return
        panelTyping = current.typing

        stepPanel.show(OverlayLayoutParams.stepPanel(typing = current.typing)) {
            AutoClickTheme {
                val live by state.collectAsStateWithLifecycle()
                live.editing?.let { editing ->
                    StepPanel(
                        editing = editing,
                        actions =
                            StepPanelActions(
                                onDraftChanged = { draft -> update { copy(editing = this.editing?.copy(draft = draft)) } },
                                onTypingChanged = { typing -> update { copy(editing = this.editing?.copy(typing = typing)) } },
                                onSave = { callbacks.onStepSaved(editing.draft) },
                                onCancel = { update { copy(editing = null) } },
                                onDelete = { callbacks.onStepDeleted(editing.draft.stepId) },
                                onMove = { by -> callbacks.onStepMoved(editing.draft.stepId, by) },
                                onGo = { by -> callbacks.onStepNavigated(editing.draft.stepId, by) },
                            ),
                    )
                }
            }
        }
    }
}

package com.pbh.autoclick.overlay

import com.pbh.autoclick.domain.overlay.Marker
import com.pbh.autoclick.domain.run.FinishReason

/**
 * What the Overlay is showing, in one value.
 *
 * The floating control has exactly two shapes (`OV-12`), and which one it wears is decided here
 * rather than by whoever last called a setter.
 */
data class OverlayUiState(
    val scenarioName: String = "",
    val markers: List<Marker> = emptyList(),
    /** OV-2: true only while the user is actually placing Markers. */
    val placingMarkers: Boolean = false,
    val run: RunState = RunState.Stopped,
    /** OV-17: why the last run ended, shown where the user is already looking. */
    val lastFinish: FinishReason? = null,
    val collapsed: Boolean = false,
) {
    /** OV-11: Markers would be tapped by the very Gestures they describe. */
    val showMarkers: Boolean get() = run is RunState.Stopped

    sealed interface RunState {
        data object Stopped : RunState

        /** OV-16: shown in the control, counting down, cancelled by the same Stop. */
        data class CountingDown(
            val remainingMilliseconds: Int,
        ) : RunState

        data class Running(
            val stepNumber: Int,
            val stepCount: Int,
        ) : RunState

        /** GX-8: a stroke is still in flight and is allowed to finish. */
        data object Stopping : RunState
    }
}

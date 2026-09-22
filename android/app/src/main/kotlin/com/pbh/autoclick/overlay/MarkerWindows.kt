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
import com.pbh.autoclick.domain.scenario.ScreenPoint
import com.pbh.autoclick.overlay.ui.MARKER_DIAMETER
import com.pbh.autoclick.overlay.ui.MarkerHandle
import com.pbh.autoclick.overlay.ui.MarkerLines
import com.pbh.autoclick.overlay.ui.handleOrigin
import kotlinx.coroutines.flow.StateFlow
import kotlin.math.roundToInt

/**
 * One window per drawn Marker, and one behind them for the lines (`OV-27`).
 *
 * The shape is forced by a gap in Android: there is no public way to say "this window answers
 * touches **here** and nowhere else". A full-screen layer either takes every touch, which makes
 * the phone unusable while Auto Click is open, or takes none, which is why placing Markers used to
 * be a mode the user had to remember to leave. A window per handle gives both at once.
 */
class MarkerWindows(
    private val context: Context,
    private val windowManager: WindowManager,
    private val state: StateFlow<OverlayUiState>,
    private val onMoved: (Marker, ScreenPoint) -> Unit,
    private val onTapped: (Marker) -> Unit,
) {
    private val lines = OverlayWindow(context, windowManager)
    private val handles = linkedMapOf<String, OverlayWindow>()

    /** OV-13: what is attached, so the coordinator can tell when the control needs the top back. */
    val signature: String get() = "${handles.keys.joinToString(",")}|${lines.isShowing}"

    /**
     * OV-11: Markers vanish entirely while anything is running.
     *
     * Not dimmed — removed. The Gestures a run dispatches land exactly where the handles are, so
     * a tap Step with these attached would tap its own Marker rather than the application below.
     */
    fun refresh(current: OverlayUiState) {
        if (!current.showMarkers || current.markers.isEmpty()) {
            dismiss()
            return
        }

        val profile = context.currentScreenProfile()
        lines.show(OverlayLayoutParams.markerLines(profile.widthPixels, profile.heightPixels)) {
            AutoClickTheme {
                val live by state.collectAsStateWithLifecycle()
                MarkerLines(markers = live.markers)
            }
        }

        val diameter = (MARKER_DIAMETER.value * context.resources.displayMetrics.density).roundToInt()
        val wanted = current.markers.associateBy { it.key }
        (handles.keys - wanted.keys).toList().forEach { handles.remove(it)?.dismiss() }
        wanted.forEach { (key, marker) -> place(key, marker, diameter) }
    }

    fun dismiss() {
        handles.values.forEach { it.dismiss() }
        handles.clear()
        lines.dismiss()
    }

    private fun place(
        key: String,
        marker: Marker,
        diameter: Int,
    ) {
        val origin = marker.handleOrigin(diameter)
        val params = OverlayLayoutParams.markerHandle(x = origin.x, y = origin.y)
        handles[key]?.let {
            it.move(params)
            return
        }

        val window = OverlayWindow(context, windowManager)
        handles[key] = window
        window.show(params) {
            AutoClickTheme {
                val live by state.collectAsStateWithLifecycle()
                // Read back out of the live state rather than closing over the Marker, so a
                // handle redraws when its Step changes instead of when its window is rebuilt.
                live.markers.firstOrNull { it.key == key }?.let { drawn ->
                    MarkerHandle(
                        marker = drawn,
                        edited = drawn.stepId == live.editedStepId,
                        onDragBy = { x, y -> moveBy(drawn, x, y) },
                        onDragFinished = {},
                        onTapped = { onTapped(drawn) },
                    )
                }
            }
        }
    }

    /** OV-10: into the Scenario's own screen, which is what its pixels mean. */
    private fun moveBy(
        marker: Marker,
        x: Int,
        y: Int,
    ) {
        val into = state.value.authoringProfile ?: context.currentScreenProfile()
        onMoved(marker, ScreenPoint(marker.point.x + x, marker.point.y + y).clampedInto(into))
    }
}

/** OV-27: what a Marker is, as opposed to where it is — so its window survives being dragged. */
internal val Marker.key: String get() = "$stepId/$role/$pathIndex"

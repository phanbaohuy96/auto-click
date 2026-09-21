package com.pbh.autoclick.overlay.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.pbh.autoclick.domain.overlay.Marker
import com.pbh.autoclick.domain.overlay.MarkerRole
import com.pbh.autoclick.domain.scenario.ScreenPoint
import java.util.UUID
import kotlin.math.roundToInt

/** How wide a Marker is. Large enough to hit with a thumb, small enough to see past. */
private val MARKER_DIAMETER = 44.dp

/** OV-21: how much wider the Marker being configured is drawn, so it can be picked out of fifteen. */
private val EDITED_BORDER = 3.dp

/**
 * Draws every Marker of the open Scenario, full screen (OV-5 to OV-9).
 *
 * [interactive] decides whether this layer answers touches at all. While it is false the window
 * itself carries `FLAG_NOT_TOUCHABLE` (`OV-2`) and these gestures never fire — the parameter is
 * here so the drawing can say so too, by dimming what cannot be moved.
 */
@Composable
fun MarkerLayer(
    markers: List<Marker>,
    interactive: Boolean,
    onMoved: (Marker, ScreenPoint) -> Unit,
    onTapped: (Marker) -> Unit,
    modifier: Modifier = Modifier,
    /** OV-21: the Step open in the panel, drawn ringed so it is obvious which one is being edited. */
    editedStepId: UUID? = null,
) {
    Box(modifier.fillMaxSize()) {
        // OV-8, OV-9: the line joining the two ends of a travelling contact, drawn once per pair.
        Canvas(Modifier.fillMaxSize()) {
            markers
                .filter { it.role == MarkerRole.SWIPE_START || it.role == MarkerRole.TOUCH_START }
                .forEach { marker ->
                    val end = marker.connectedTo ?: return@forEach
                    drawLine(
                        color = Color.White.copy(alpha = if (interactive) 0.9f else 0.5f),
                        start = Offset(marker.point.x.toFloat(), marker.point.y.toFloat()),
                        end = Offset(end.x.toFloat(), end.y.toFloat()),
                        strokeWidth = Stroke.HairlineWidth + 4f,
                    )
                }
        }

        markers.forEach { marker ->
            MarkerHandle(
                marker = marker,
                interactive = interactive,
                edited = marker.stepId == editedStepId,
                onMoved = { onMoved(marker, it) },
                onTapped = { onTapped(marker) },
            )
        }
    }
}

@Composable
private fun MarkerHandle(
    marker: Marker,
    interactive: Boolean,
    edited: Boolean,
    onMoved: (ScreenPoint) -> Unit,
    onTapped: () -> Unit,
) {
    val diameter = MARKER_DIAMETER
    Box(
        contentAlignment = Alignment.Center,
        modifier =
            Modifier
                .offset {
                    // Raw pixels, centred on the point the Step will actually touch (SM-11).
                    IntOffset(
                        x = marker.point.x - (diameter.toPx() / 2).roundToInt(),
                        y = marker.point.y - (diameter.toPx() / 2).roundToInt(),
                    )
                }.size(diameter)
                .clip(CircleShape)
                .background(marker.colour(interactive || edited))
                .then(if (edited) Modifier.border(EDITED_BORDER, Color.White, CircleShape) else Modifier)
                .pointerInput(marker.stepId, marker.role, marker.pathIndex, interactive) {
                    if (!interactive) return@pointerInput
                    detectDragGestures { change, _ ->
                        change.consume()
                        // The position is reported inside this handle, so the point it names is the
                        // handle's own origin plus where the finger is within it.
                        onMoved(
                            ScreenPoint(
                                x = marker.point.x + (change.position.x - size.width / 2).roundToInt(),
                                y = marker.point.y + (change.position.y - size.height / 2).roundToInt(),
                            ),
                        )
                    }
                }.pointerInput(marker.stepId, interactive) {
                    if (!interactive) return@pointerInput
                    detectTapGestures { onTapped() }
                },
    ) {
        Text(
            text = marker.label(),
            style = MaterialTheme.typography.labelLarge,
            color = Color.White,
        )
    }
}

/** OV-8: the end of a swipe is an arrow, not a second copy of the number. */
private fun Marker.label(): String =
    when (role) {
        MarkerRole.SWIPE_END, MarkerRole.TOUCH_END -> "→"
        else -> stepNumber.toString()
    }

private fun Marker.colour(interactive: Boolean): Color {
    val base =
        when (role) {
            MarkerRole.POINT -> Color(0xFF2962FF)
            MarkerRole.SWIPE_START, MarkerRole.SWIPE_END -> Color(0xFF00897B)
            MarkerRole.TOUCH_START, MarkerRole.TOUCH_END -> Color(0xFF6A1B9A)
        }
    return if (interactive) base else base.copy(alpha = 0.45f)
}

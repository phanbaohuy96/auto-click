package com.pbh.autoclick.overlay.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
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
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.pbh.autoclick.core.overlay.windowDragHandle
import com.pbh.autoclick.domain.overlay.Marker
import com.pbh.autoclick.domain.overlay.MarkerRole
import com.pbh.autoclick.domain.scenario.ScreenPoint

/** How wide a Marker is. Large enough to hit with a thumb, small enough to see past. */
val MARKER_DIAMETER: Dp = 44.dp

/** OV-21: how much wider the Marker being configured is drawn, so it can be picked out of fifteen. */
private val EDITED_BORDER = 3.dp

/**
 * One Marker, in a window of its own (OV-7, OV-27).
 *
 * A window per handle is what lets a Marker be dragged and tapped **while the application
 * underneath stays usable**: everything outside these few dozen pixels reaches whatever is below.
 * It replaced a full-screen layer with a mode the user had to remember to leave, which is the
 * shape `landscape.md` records as the category's seventh-worst complaint.
 */
@Composable
fun MarkerHandle(
    marker: Marker,
    edited: Boolean,
    onDragBy: (x: Int, y: Int) -> Unit,
    onDragFinished: () -> Unit,
    onTapped: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        contentAlignment = Alignment.Center,
        modifier =
            modifier
                .size(MARKER_DIAMETER)
                .clip(CircleShape)
                .background(marker.colour())
                .then(if (edited) Modifier.border(EDITED_BORDER, Color.White, CircleShape) else Modifier)
                .windowDragHandle(
                    onDragBy = onDragBy,
                    onDragFinished = onDragFinished,
                    onTap = onTapped,
                ),
    ) {
        Text(
            text = marker.label(),
            style = MaterialTheme.typography.labelLarge,
            color = Color.White,
        )
    }
}

/**
 * The lines joining the two ends of every travelling Marker pair (OV-8, OV-9).
 *
 * Its own full-screen window, and one that never takes a touch. The handles are what the user
 * grabs; this only says which of them belong together.
 */
@Composable
fun MarkerLines(
    markers: List<Marker>,
    modifier: Modifier = Modifier,
) {
    Canvas(modifier.fillMaxSize()) {
        markers
            .filter { it.role == MarkerRole.SWIPE_START || it.role == MarkerRole.TOUCH_START }
            .forEach { marker ->
                val end = marker.connectedTo ?: return@forEach
                drawLine(
                    color = Color.White.copy(alpha = 0.9f),
                    start = Offset(marker.point.x.toFloat(), marker.point.y.toFloat()),
                    end = Offset(end.x.toFloat(), end.y.toFloat()),
                    strokeWidth = Stroke.HairlineWidth + 4f,
                )
            }
    }
}

/** Where a handle's window goes, given that the Marker names the point its Step will touch. */
fun Marker.handleOrigin(diameterPixels: Int): ScreenPoint = ScreenPoint(x = point.x - diameterPixels / 2, y = point.y - diameterPixels / 2)

/** OV-8: the end of a swipe is an arrow, not a second copy of the number. */
private fun Marker.label(): String =
    when (role) {
        MarkerRole.SWIPE_END, MarkerRole.TOUCH_END -> "→"
        else -> stepNumber.toString()
    }

private fun Marker.colour(): Color =
    when (role) {
        MarkerRole.POINT -> Color(0xFF2962FF)
        MarkerRole.SWIPE_START, MarkerRole.SWIPE_END -> Color(0xFF00897B)
        MarkerRole.TOUCH_START, MarkerRole.TOUCH_END -> Color(0xFF6A1B9A)
    }

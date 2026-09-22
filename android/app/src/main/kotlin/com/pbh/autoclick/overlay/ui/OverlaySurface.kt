package com.pbh.autoclick.overlay.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.pbh.autoclick.core.overlay.windowDragHandle

/** DS-4: how far an Overlay window lifts off whatever it is drawn on. */
private val OVERLAY_ELEVATION = 12.dp

/**
 * A window the user can see the edge of, whatever is behind it (`DS-4`).
 *
 * Both halves are load-bearing and were arrived at by looking. The **hairline** is what gives the
 * control an edge over a dark wallpaper, where the surface itself is the same value as the
 * background and the window simply vanishes. The **shadow** is what gives it one over a light
 * screen, where the hairline is doing much less work. Neither alone covers both.
 */
@Composable
fun OverlaySurface(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(22.dp),
    content: @Composable () -> Unit,
) {
    Surface(
        modifier = modifier,
        shape = shape,
        color = MaterialTheme.colorScheme.surfaceContainer,
        contentColor = MaterialTheme.colorScheme.onSurface,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline),
        shadowElevation = OVERLAY_ELEVATION,
        content = content,
    )
}

/**
 * OV-14: what the user takes hold of to move the control.
 *
 * Its own target rather than the whole control, for two reasons. A drag that begins on a button
 * has to be told apart from a press of that button, and this way it never has to be; and a handle
 * that looks like a handle is the only thing on the control that says it can be moved at all.
 */
@Composable
fun DragGrip(
    onDragBy: (Int, Int) -> Unit,
    onDragFinished: () -> Unit,
    modifier: Modifier = Modifier,
    height: Dp = 46.dp,
) {
    Box(
        contentAlignment = Alignment.Center,
        modifier =
            modifier
                .size(width = 22.dp, height = height)
                .windowDragHandle(onDragBy = onDragBy, onDragFinished = onDragFinished),
    ) {
        Surface(
            shape = CircleShape,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(width = 3.5.dp, height = 20.dp),
            content = {},
        )
    }
}

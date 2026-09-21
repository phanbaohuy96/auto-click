package com.pbh.autoclick.overlay.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Done
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.pbh.autoclick.R
import com.pbh.autoclick.domain.run.FinishReason
import com.pbh.autoclick.overlay.OverlayUiState

/**
 * The control that is always reachable, in both of its states (OV-12, OV-13).
 *
 * Stop is the largest target while running, and nothing is ever drawn over it: a run that cannot
 * be stopped is the failure this whole app is written around.
 */
@Composable
fun FloatingControl(
    state: OverlayUiState,
    actions: FloatingControlActions,
    modifier: Modifier = Modifier,
) {
    if (state.collapsed) {
        CollapsedBubble(modifier = modifier, onClick = actions.onToggleCollapsed)
        return
    }

    Column(
        modifier =
            modifier
                .clip(RoundedCornerShape(24.dp))
                .background(MaterialTheme.colorScheme.surface)
                .padding(horizontal = 12.dp, vertical = 8.dp)
                .widthIn(max = 320.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        when (val run = state.run) {
            OverlayUiState.RunState.Stopped -> {
                state.lastFinish?.let {
                    // OV-17: the reason is shown here, not only in a notification.
                    Text(
                        text = it.describeFinish(),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
                StoppedRow(placingMarkers = state.placingMarkers, actions = actions)
            }

            is OverlayUiState.RunState.CountingDown ->
                RunningColumn(
                    caption = stringResource(R.string.overlay_starting_in, run.remainingMilliseconds / 1000 + 1),
                    onStop = actions.onStop,
                )

            is OverlayUiState.RunState.Running ->
                RunningColumn(
                    caption = stringResource(R.string.overlay_step_of, run.stepNumber, run.stepCount),
                    onStop = actions.onStop,
                )

            OverlayUiState.RunState.Stopping ->
                RunningColumn(
                    caption = stringResource(R.string.overlay_stopping),
                    onStop = {},
                )
        }
    }
}

/** Every button on the control, in one value, so the signature stays readable. */
data class FloatingControlActions(
    val onStart: () -> Unit,
    val onStop: () -> Unit,
    val onAddStep: () -> Unit,
    val onTogglePlacing: () -> Unit,
    val onFreeTheTouch: () -> Unit,
    val onToggleCollapsed: () -> Unit,
)

@Composable
private fun StoppedRow(
    placingMarkers: Boolean,
    actions: FloatingControlActions,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = actions.onStart) {
            Icon(Icons.Default.PlayArrow, contentDescription = stringResource(R.string.overlay_start))
        }
        IconButton(onClick = actions.onAddStep) {
            Icon(Icons.Default.Add, contentDescription = stringResource(R.string.overlay_add_step))
        }
        IconButton(onClick = actions.onTogglePlacing) {
            Icon(
                imageVector = if (placingMarkers) Icons.Default.Done else Icons.Default.Edit,
                contentDescription =
                    stringResource(
                        if (placingMarkers) R.string.overlay_finish_placing else R.string.overlay_place_markers,
                    ),
            )
        }
        // OV-15: also a notification action, because a latched touch is exactly when this window
        // cannot be tapped.
        IconButton(onClick = actions.onFreeTheTouch) {
            Icon(Icons.Default.Refresh, contentDescription = stringResource(R.string.overlay_free_the_touch))
        }
        IconButton(onClick = actions.onToggleCollapsed) {
            Icon(Icons.Default.KeyboardArrowDown, contentDescription = stringResource(R.string.overlay_collapse))
        }
    }
}

@Composable
private fun RunningColumn(
    caption: String,
    onStop: () -> Unit,
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(caption, style = MaterialTheme.typography.labelMedium)
        // OV-13: the largest target on the control, at every moment of a run.
        IconButton(onClick = onStop, modifier = Modifier.size(72.dp)) {
            Icon(
                imageVector = Icons.Default.Close,
                contentDescription = stringResource(R.string.overlay_stop),
                modifier = Modifier.size(48.dp),
            )
        }
    }
}

@Composable
private fun CollapsedBubble(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    IconButton(
        onClick = onClick,
        modifier =
            modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.primaryContainer),
    ) {
        Icon(Icons.Default.KeyboardArrowUp, contentDescription = stringResource(R.string.overlay_expand))
    }
}

/** OV-17: why the last run ended, in one line, where the user is already looking. */
@Composable
private fun FinishReason.describeFinish(): String =
    when (this) {
        FinishReason.Completed -> stringResource(R.string.overlay_finished)
        FinishReason.Stopped -> stringResource(R.string.overlay_stopped)
        is FinishReason.ScreenProfileMismatch -> stringResource(R.string.overlay_screen_changed)
        is FinishReason.GestureCancelled -> stringResource(R.string.overlay_gesture_cancelled, stepIndex + 1)
        is FinishReason.NoFocusedField -> stringResource(R.string.overlay_no_field, stepIndex + 1)
        is FinishReason.GlobalActionRefused -> stringResource(R.string.overlay_action_refused, stepIndex + 1)
    }

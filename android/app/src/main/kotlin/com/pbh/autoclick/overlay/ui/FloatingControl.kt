package com.pbh.autoclick.overlay.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Done
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pbh.autoclick.R
import com.pbh.autoclick.core.overlay.windowDragHandle
import com.pbh.autoclick.domain.run.FinishReason
import com.pbh.autoclick.overlay.OverlayUiState

/**
 * The control that is always reachable, in both of its shapes (OV-12, OV-13, OV-14).
 *
 * Stop is the largest target while running, and nothing is ever drawn over it: a run that cannot
 * be stopped is the failure this whole app is written around.
 *
 * Four buttons and no more. `landscape.md` ranks "controls that sit on top of what you are
 * automating" seventh among the category's complaints and "steep learning curve" ninth, and both
 * are paid for in width. Everything that is not Start, Add, Steps or Collapse lives one tap away
 * in the panel.
 */
@Composable
fun FloatingControl(
    state: OverlayUiState,
    actions: FloatingControlActions,
    modifier: Modifier = Modifier,
) {
    if (state.collapsed) {
        CollapsedBubble(state = state, actions = actions, modifier = modifier)
        return
    }

    OverlaySurface(modifier = modifier.widthIn(max = 340.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            DragGrip(onDragBy = actions.onDragBy, onDragFinished = actions.onDragFinished)

            Column(
                modifier = Modifier.padding(end = 10.dp, top = 6.dp, bottom = 6.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                when (val run = state.run) {
                    OverlayUiState.RunState.Stopped ->
                        if (state.isRecording) {
                            RecordingColumn(touches = state.recording?.touches ?: 0, actions = actions)
                        } else {
                            Caption(state)
                            StoppedRow(actions)
                        }

                    is OverlayUiState.RunState.CountingDown ->
                        RunningColumn(
                            caption = stringResource(R.string.overlay_starting_in, run.remainingMilliseconds / 1000 + 1),
                            actions = actions,
                        )

                    is OverlayUiState.RunState.Running ->
                        RunningColumn(
                            caption = stringResource(R.string.overlay_step_of, run.stepNumber, run.stepCount),
                            actions = actions,
                        )

                    OverlayUiState.RunState.Stopping ->
                        RunningColumn(
                            caption = stringResource(R.string.overlay_stopping),
                            actions = actions,
                            onStop = null,
                        )
                }
            }
        }
    }
}

/** Every button on the control, in one value, so the signature stays readable. */
data class FloatingControlActions(
    val onStart: () -> Unit,
    val onStop: () -> Unit,
    /** RD-1: begins swallowing touches, recording them, and handing them on. */
    val onRecord: () -> Unit,
    /** RD-3: ends the session and turns what was caught into Steps. */
    val onStopRecording: () -> Unit,
    val onAddStep: () -> Unit,
    val onOpenPanel: () -> Unit,
    val onFreeTheTouch: () -> Unit,
    val onToggleCollapsed: () -> Unit,
    /** OV-14: a delta in raw screen pixels, because the window moves out from under the finger. */
    val onDragBy: (x: Int, y: Int) -> Unit,
    val onDragFinished: () -> Unit,
)

@Composable
private fun Caption(state: OverlayUiState) {
    val finish = state.lastFinish
    if (finish != null) {
        // OV-17: the reason is shown here, not only in a notification.
        Text(
            text = finish.describeFinish(),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.error,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        return
    }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = state.scenarioName,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(weight = 1f, fill = false),
        )
        Text(
            text = "  ${pluralStringResource(R.plurals.overlay_steps, state.stepCount, state.stepCount)}",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
        )
    }
}

@Composable
private fun StoppedRow(actions: FloatingControlActions) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // The one accent on the control: Start is what it is for, and everything else on the row
        // is a way of getting ready to press it.
        IconButton(onClick = actions.onStart) {
            Icon(
                imageVector = Icons.Default.PlayArrow,
                contentDescription = stringResource(R.string.overlay_start),
                tint = MaterialTheme.colorScheme.primary,
            )
        }
        // RD-1: next to Start, because recording and running are the two things this app does and
        // everything else on the row is preparation for one of them.
        IconButton(onClick = actions.onRecord) {
            Icon(
                painter = painterResource(R.drawable.ic_record),
                contentDescription = stringResource(R.string.overlay_record),
                tint = MaterialTheme.colorScheme.error,
            )
        }
        IconButton(onClick = actions.onAddStep) {
            Icon(Icons.Default.Add, contentDescription = stringResource(R.string.overlay_add_step))
        }
        IconButton(onClick = actions.onOpenPanel) {
            Icon(Icons.AutoMirrored.Filled.List, contentDescription = stringResource(R.string.overlay_open_panel))
        }
        IconButton(onClick = actions.onToggleCollapsed) {
            Icon(Icons.Default.KeyboardArrowDown, contentDescription = stringResource(R.string.overlay_collapse))
        }
    }
}

/**
 * OV-13: Stop is the largest target on the control at every moment of a run.
 *
 * [onStop] is null once the runner has been asked and is finishing its last stroke (`GX-8`) —
 * asking twice does nothing, and a button that does nothing should not look pressable.
 *
 * "Free the touch" sits beside it because a run is when a latched touch happens (`GX-11`). It is
 * small on purpose: the notification and the Quick Settings tile are the copies meant for the
 * moment when no Overlay can be tapped at all.
 */
@Composable
private fun RunningColumn(
    caption: String,
    actions: FloatingControlActions,
    onStop: (() -> Unit)? = actions.onStop,
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = caption,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            // Filled rather than outlined, and in the error colour: this is the button whose whole
            // job is to be found without being looked for.
            Surface(
                onClick = { onStop?.invoke() },
                enabled = onStop != null,
                shape = CircleShape,
                color = MaterialTheme.colorScheme.error,
                contentColor = MaterialTheme.colorScheme.onError,
                modifier = Modifier.size(64.dp),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = stringResource(R.string.overlay_stop),
                        modifier = Modifier.size(34.dp),
                    )
                }
            }
            IconButton(onClick = actions.onFreeTheTouch) {
                Icon(
                    painter = painterResource(R.drawable.ic_free_the_touch),
                    contentDescription = stringResource(R.string.overlay_free_the_touch),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

/**
 * RD-6: what the control says while it is swallowing the user's touches.
 *
 * The count is there because a recording session gives no other feedback — the application
 * underneath reacts exactly as it would to a finger, which is the point of `RD-5` and also the
 * reason nothing on screen would otherwise say the session is still running.
 *
 * Finishing is a **tick and the accent colour**, not a red cross. Stopping a recording keeps what
 * was caught; a cross would promise the opposite.
 */
@Composable
private fun RecordingColumn(
    touches: Int,
    actions: FloatingControlActions,
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = pluralStringResource(R.plurals.overlay_recorded, touches, touches),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Surface(
            onClick = actions.onStopRecording,
            shape = CircleShape,
            color = MaterialTheme.colorScheme.primary,
            contentColor = MaterialTheme.colorScheme.onPrimary,
            modifier = Modifier.size(64.dp),
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(
                    imageVector = Icons.Default.Done,
                    contentDescription = stringResource(R.string.overlay_stop_recording),
                    modifier = Modifier.size(34.dp),
                )
            }
        }
    }
}

/**
 * OV-12: what is left when the control is in the way.
 *
 * It keeps saying whether something is running, because a control small enough to forget is a
 * control that can be running without the user noticing.
 */
@Composable
private fun CollapsedBubble(
    state: OverlayUiState,
    actions: FloatingControlActions,
    modifier: Modifier = Modifier,
) {
    val colours = MaterialTheme.colorScheme
    Box(
        contentAlignment = Alignment.Center,
        modifier =
            modifier
                .size(50.dp)
                .clip(CircleShape)
                .background(if (state.running || state.isRecording) colours.error else colours.surfaceContainer)
                .border(1.dp, colours.outline, CircleShape)
                .windowDragHandle(
                    onDragBy = actions.onDragBy,
                    onDragFinished = actions.onDragFinished,
                    onTap = actions.onToggleCollapsed,
                ),
    ) {
        if (state.running || state.isRecording) {
            // The step number rather than an icon: collapsed is exactly when the user cannot see
            // the caption, and "how far has it got" is the one thing they will want from a glance.
            Text(
                text =
                    state.recording?.touches?.toString()
                        ?: (state.run as? OverlayUiState.RunState.Running)?.stepNumber?.toString()
                        ?: "…",
                style = MaterialTheme.typography.titleMedium,
                color = colours.onError,
            )
        } else {
            Icon(
                imageVector = Icons.Default.PlayArrow,
                contentDescription = stringResource(R.string.overlay_expand),
                tint = colours.primary,
            )
        }
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

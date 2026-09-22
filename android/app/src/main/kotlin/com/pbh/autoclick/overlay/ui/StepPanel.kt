package com.pbh.autoclick.overlay.ui

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.pbh.autoclick.R
import com.pbh.autoclick.domain.editor.StepActionKind
import com.pbh.autoclick.domain.editor.StepDraft
import com.pbh.autoclick.domain.scenario.ScenarioLimits
import com.pbh.autoclick.overlay.EditingStep

/**
 * The third Overlay window (`OV-1`): one Step, open for configuration, as a sheet (`OV-34`).
 *
 * It edits everything about a Step **except where it touches**. Points belong to the Marker layer,
 * where the user can see what they are aiming at (`OV-7`, `OV-21`), and two ways to set the same
 * value would only disagree with each other.
 *
 * Save is offered only when the Step has no violations (`OV-22`, `SM-17`) and is pinned below the
 * scrolling body, so a long Step cannot hide the button that commits it. Delete and the two move
 * buttons apply at once, because they change the Scenario's shape rather than this Step's fields —
 * the same immediacy dragging a Marker already has.
 */
@Composable
fun StepPanel(
    editing: EditingStep,
    actions: StepPanelActions,
    modifier: Modifier = Modifier,
) {
    // OV-20: how many fields hold the caret, not whether the last event was a gain. A focus moving
    // from one field to the next reports a loss and a gain in the same frame, and a boolean would
    // drop the window out of focus in between — taking the keyboard with it.
    var focusedFields by remember { mutableIntStateOf(0) }
    val typing = focusedFields > 0
    LaunchedEffect(typing) { actions.onTypingChanged(typing) }
    val onFocus: (Boolean) -> Unit = { gained -> focusedFields += if (gained) 1 else -1 }

    OverlayBottomSheet(
        modifier = modifier,
        header = { PanelHeader(editing, actions) },
        footer = { PanelFooter(editing, actions) },
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(bottom = 12.dp)) {
            ActionSection(editing.draft) { actions.onDraftChanged(editing.draft.copy(kind = it)) }

            // Keyed so the fields' own text state starts fresh when the Step or its Action changes,
            // instead of a hold duration being shown in a swipe's duration box.
            key(editing.draft.stepId, editing.draft.kind) {
                StepActionFields(editing = editing, onDraft = actions.onDraftChanged, onFocus = onFocus)
                CommonFields(editing.draft, actions.onDraftChanged, onFocus)
            }

            editing.violations.forEach {
                Text(
                    text = it.describe(),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }
    }
}

/** Everything the panel can do, in one value, so the signature stays readable. */
data class StepPanelActions(
    val onDraftChanged: (StepDraft) -> Unit,
    val onTypingChanged: (Boolean) -> Unit,
    val onSave: () -> Unit,
    val onCancel: () -> Unit,
    val onDelete: () -> Unit,
    /** OV-6: -1 moves the Step one place earlier, +1 one place later. */
    val onMove: (Int) -> Unit,
    /** OV-24: -1 opens the previous Step in the Scenario, +1 the next. */
    val onGo: (Int) -> Unit,
)

/** OV-6: the Step's number, which is the one thing a spatial layout cannot show by itself. */
@Composable
private fun PanelHeader(
    editing: EditingStep,
    actions: StepPanelActions,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
    ) {
        // OV-24: the only way to reach a Step that draws no Marker (`SM-8`). Without these, a
        // setText or globalAction Step can be written once and never opened again.
        IconButton(onClick = { actions.onGo(-1) }, enabled = editing.canGoBack) {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, contentDescription = stringResource(R.string.step_previous))
        }
        Text(
            text = stringResource(R.string.step_panel_title, editing.stepNumber, editing.stepCount),
            style = MaterialTheme.typography.titleMedium,
        )
        IconButton(onClick = { actions.onGo(1) }, enabled = editing.canGoForward) {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = stringResource(R.string.step_next))
        }
        Spacer(Modifier.weight(1f))
        IconButton(onClick = { actions.onMove(-1) }, enabled = editing.canMoveUp) {
            Icon(Icons.Default.KeyboardArrowUp, contentDescription = stringResource(R.string.step_move_up))
        }
        IconButton(onClick = { actions.onMove(1) }, enabled = editing.canMoveDown) {
            Icon(Icons.Default.ArrowDropDown, contentDescription = stringResource(R.string.step_move_down))
        }
        IconButton(onClick = actions.onDelete) {
            Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.step_delete))
        }
        IconButton(onClick = actions.onCancel) {
            Icon(Icons.Default.Close, contentDescription = stringResource(R.string.step_cancel))
        }
    }
}

/** OV-22: Save is pinned, so a Step tall enough to scroll cannot hide the way to commit it. */
@Composable
private fun PanelFooter(
    editing: EditingStep,
    actions: StepPanelActions,
) {
    Row(
        horizontalArrangement = Arrangement.End,
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
    ) {
        TextButton(onClick = actions.onCancel) { Text(stringResource(R.string.step_cancel)) }
        Spacer(Modifier.padding(horizontal = 4.dp))
        Button(onClick = actions.onSave, enabled = editing.canSave) {
            Text(stringResource(R.string.step_save))
        }
    }
}

/**
 * SM-7: the five Actions, all visible at once so the choice needs no menu to discover — under a
 * heading that says what the row is.
 *
 * The heading and the line under it are not decoration. Five unlabelled chips at the top of a
 * sheet read as filters, which is what chips usually are; nothing said that picking one changes
 * what the Step *does*. The sentence underneath says it in the Step's own terms, and it changes
 * with the selection, so the answer is there before the question is asked.
 */
@Composable
private fun ActionSection(
    draft: StepDraft,
    onKind: (StepActionKind) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            text = stringResource(R.string.step_action_heading),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Row(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
        ) {
            StepActionKind.entries.forEach { kind ->
                FilterChip(
                    selected = kind == draft.kind,
                    onClick = { onKind(kind) },
                    label = { Text(kind.label()) },
                )
            }
        }
        Text(
            text = draft.kind.describeKind(),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

/** SM-5: the two properties every Step has, whichever Action it carries. */
@Composable
private fun CommonFields(
    draft: StepDraft,
    onDraft: (StepDraft) -> Unit,
    onFocus: (Boolean) -> Unit,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        NumberField(
            label = stringResource(R.string.step_repeat),
            value = draft.repeatCount.toLong(),
            onValue = { onDraft(draft.copy(repeatCount = it.toInt())) },
            onFocus = onFocus,
            modifier = Modifier.weight(1f),
            range = ScenarioLimits.stepRepeatCount.toLongRange(),
        )
        NumberField(
            label = stringResource(R.string.step_delay),
            value = draft.delayMillisecondsAfter.toLong(),
            onValue = { onDraft(draft.copy(delayMillisecondsAfter = it.toInt())) },
            onFocus = onFocus,
            modifier = Modifier.weight(1f),
            range = ScenarioLimits.delayMilliseconds.toLongRange(),
        )
    }
}

@Composable
private fun StepActionKind.label(): String =
    stringResource(
        when (this) {
            StepActionKind.TAP -> R.string.step_kind_tap
            StepActionKind.SWIPE -> R.string.step_kind_swipe
            StepActionKind.MULTI_TOUCH -> R.string.step_kind_multi_touch
            StepActionKind.GLOBAL_ACTION -> R.string.step_kind_global
            StepActionKind.SET_TEXT -> R.string.step_kind_text
        },
    )

/** One sentence per Action, in the Step's own terms rather than the platform's. */
@Composable
private fun StepActionKind.describeKind(): String =
    stringResource(
        when (this) {
            StepActionKind.TAP -> R.string.step_about_tap
            StepActionKind.SWIPE -> R.string.step_about_swipe
            StepActionKind.MULTI_TOUCH -> R.string.step_about_multi_touch
            StepActionKind.GLOBAL_ACTION -> R.string.step_about_global
            StepActionKind.SET_TEXT -> R.string.step_about_text
        },
    )

private fun IntRange.toLongRange(): LongRange = first.toLong()..last.toLong()

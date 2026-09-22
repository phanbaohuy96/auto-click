package com.pbh.autoclick.overlay.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pbh.autoclick.R
import com.pbh.autoclick.domain.scenario.RunCount
import com.pbh.autoclick.domain.scenario.Scenario
import com.pbh.autoclick.domain.scenario.ScenarioLimits
import com.pbh.autoclick.domain.scenario.Step
import java.util.UUID

private const val MILLISECONDS_PER_SECOND = 1_000

/**
 * The Scenario as a whole: its name, how often it runs, and every Step in order (`OV-28`).
 *
 * This is the half of the editor that was missing. Before it, a Scenario could only ever be called
 * "Untitled" and run exactly once, because `Scenario.name`, `runCount` and `countdownMilliseconds`
 * had no way in — and a Step with no Marker (`SM-8`) could only be reached by walking to it from a
 * Step that had one.
 */
@Composable
fun ScenarioPanel(
    scenario: Scenario,
    actions: ScenarioPanelActions,
    modifier: Modifier = Modifier,
) {
    // OV-20, exactly as the Step panel counts it: a count rather than a boolean, so focus moving
    // between two fields does not drop the window out of focus in between.
    var focusedFields by remember { mutableIntStateOf(0) }
    val typing = focusedFields > 0
    LaunchedEffect(typing) { actions.onTypingChanged(typing) }
    val onFocus: (Boolean) -> Unit = { gained -> focusedFields += if (gained) 1 else -1 }

    OverlayBottomSheet(
        modifier = modifier,
        header = { Header(scenario, actions) },
        footer = { Footer(actions) },
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.padding(bottom = 12.dp),
        ) {
            key(scenario.id) {
                NameField(scenario, actions, onFocus)
                RunSettings(scenario, actions, onFocus)
            }

            HorizontalDivider()
            StepList(scenario, actions)
        }
    }
}

/** Everything the Scenario panel can do, in one value, so the signature stays readable. */
data class ScenarioPanelActions(
    val onRenamed: (String) -> Unit,
    val onRunCountChanged: (RunCount) -> Unit,
    val onCountdownChanged: (Int) -> Unit,
    val onTypingChanged: (Boolean) -> Unit,
    val onAddStep: () -> Unit,
    val onOpenStep: (UUID) -> Unit,
    /** OV-6: -1 moves the Step one place earlier, +1 one place later. */
    val onMoveStep: (UUID, Int) -> Unit,
    val onDeleteStep: (UUID) -> Unit,
    val onFreeTheTouch: () -> Unit,
    val onOpenApp: () -> Unit,
    val onCloseOverlay: () -> Unit,
    val onDismiss: () -> Unit,
)

@Composable
private fun Header(
    scenario: Scenario,
    actions: ScenarioPanelActions,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(start = 16.dp, end = 8.dp),
    ) {
        // OV-33: the Scenario's name lives here now. The floating control gave it up to become one
        // row tall, and this is the screen where the name can also be changed.
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = scenario.name,
                style = MaterialTheme.typography.titleMedium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = pluralStringResource(R.plurals.overlay_steps, scenario.steps.size, scenario.steps.size),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        IconButton(onClick = actions.onAddStep) {
            Icon(Icons.Default.Add, contentDescription = stringResource(R.string.overlay_add_step))
        }
        IconButton(onClick = actions.onDismiss) {
            Icon(Icons.Default.Close, contentDescription = stringResource(R.string.step_cancel))
        }
    }
}

/**
 * FS-15: the name is saved as it is typed, like everything else about a Scenario.
 *
 * A blank name is kept blank in the field and refused on the way out, rather than snapping back to
 * something while the user is still mid-word.
 */
@Composable
private fun NameField(
    scenario: Scenario,
    actions: ScenarioPanelActions,
    onFocus: (Boolean) -> Unit,
) {
    LabelledTextField(
        label = stringResource(R.string.scenario_name),
        value = scenario.name,
        onValue = actions.onRenamed,
        onFocus = onFocus,
    )
}

/** SM-2, SM-3: how many times the whole Scenario runs, and how long before the first Step. */
@Composable
private fun RunSettings(
    scenario: Scenario,
    actions: ScenarioPanelActions,
    onFocus: (Boolean) -> Unit,
) {
    val untilStopped = scenario.runCount is RunCount.UntilStopped

    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        FilterChip(
            selected = untilStopped,
            onClick = {
                actions.onRunCountChanged(
                    if (untilStopped) RunCount.Times(1) else RunCount.UntilStopped,
                )
            },
            label = { Text(stringResource(R.string.scenario_until_stopped)) },
        )
        if (!untilStopped) {
            NumberField(
                label = stringResource(R.string.scenario_run_count),
                value = (scenario.runCount as RunCount.Times).count.toLong(),
                onValue = { actions.onRunCountChanged(RunCount.Times(it.toInt())) },
                onFocus = onFocus,
                modifier = Modifier.weight(1f),
                range = ScenarioLimits.runCount.first.toLong()..ScenarioLimits.runCount.last.toLong(),
            )
        }
        NumberField(
            label = stringResource(R.string.scenario_countdown),
            value = (scenario.countdownMilliseconds / MILLISECONDS_PER_SECOND).toLong(),
            onValue = { actions.onCountdownChanged((it * MILLISECONDS_PER_SECOND).toInt()) },
            onFocus = onFocus,
            modifier = Modifier.weight(1f),
            range = 0L..(ScenarioLimits.countdownMilliseconds.last / MILLISECONDS_PER_SECOND).toLong(),
        )
    }
}

/**
 * OV-28: every Step, in order, reachable whether or not it draws a Marker.
 *
 * The list is the answer to `SM-8`. A `setText` or `globalAction` Step has nothing on the screen
 * to tap, and before this the only route to one was walking to it from a neighbour that did.
 */
@Composable
private fun StepList(
    scenario: Scenario,
    actions: ScenarioPanelActions,
) {
    if (scenario.steps.isEmpty()) {
        Text(
            text = stringResource(R.string.scenario_no_steps),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        return
    }

    scenario.steps.forEachIndexed { index, step ->
        StepRow(
            step = step,
            number = index + 1,
            canMoveUp = index > 0,
            canMoveDown = index < scenario.steps.lastIndex,
            actions = actions,
        )
    }
}

@Composable
private fun StepRow(
    step: Step,
    number: Int,
    canMoveUp: Boolean,
    canMoveDown: Boolean,
    actions: ScenarioPanelActions,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().clickable { actions.onOpenStep(step.id) },
    ) {
        Text(
            text = number.toString(),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.widthIn(min = 24.dp),
        )
        Text(
            text = step.summary(),
            style = MaterialTheme.typography.bodyMedium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        IconButton(onClick = { actions.onMoveStep(step.id, -1) }, enabled = canMoveUp) {
            Icon(Icons.Default.KeyboardArrowUp, contentDescription = stringResource(R.string.step_move_up))
        }
        IconButton(onClick = { actions.onMoveStep(step.id, 1) }, enabled = canMoveDown) {
            Icon(Icons.Default.ArrowDropDown, contentDescription = stringResource(R.string.step_move_down))
        }
        IconButton(onClick = { actions.onDeleteStep(step.id) }) {
            Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.step_delete))
        }
    }
}

/**
 * The three things that have nowhere else to live.
 *
 * "Free the touch" is here as well as on the running control, the notification and the Quick
 * Settings tile (`GX-11`, `GX-12`). The copies that matter in an emergency are the last two — no
 * Overlay can be tapped while a touch is latched — and this one is simply where a user who is
 * reading rather than panicking will look for it.
 */
@Composable
private fun Footer(actions: ScenarioPanelActions) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth(),
    ) {
        TextButton(onClick = actions.onFreeTheTouch) {
            Icon(Icons.Default.Refresh, contentDescription = null)
            Spacer(Modifier.widthIn(min = 6.dp))
            Text(stringResource(R.string.overlay_free_the_touch))
        }
        Spacer(Modifier.weight(1f))
        IconButton(onClick = actions.onOpenApp) {
            Icon(Icons.AutoMirrored.Filled.ExitToApp, contentDescription = stringResource(R.string.overlay_open_app))
        }
        TextButton(onClick = actions.onCloseOverlay) { Text(stringResource(R.string.overlay_close)) }
    }
}

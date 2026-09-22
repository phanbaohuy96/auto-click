package com.pbh.autoclick.feature.scenario.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.LifecycleResumeEffect
import com.pbh.autoclick.R
import com.pbh.autoclick.core.ui.BaseScreen
import com.pbh.autoclick.domain.repository.StoredScenario
import com.pbh.autoclick.feature.onboarding.readPermissionStatus
import com.pbh.autoclick.overlay.OverlayService

/**
 * The Activity surface: set the app up, manage Scenarios, and hand one to the Overlay.
 *
 * Nothing is authored here, and since `OV-26` nothing is even watched here: opening a Scenario
 * starts [OverlayService] and then sends this Activity to the back, because the application the
 * user wants to automate is somewhere else. See [ADR-0015] on why the two surfaces are separate.
 */
@Composable
fun ScenarioListScreen(
    onSetUp: () -> Unit,
    viewModel: ScenarioListViewModel = hiltViewModel(),
) {
    val context = LocalContext.current
    var ready by remember { mutableStateOf(context.readPermissionStatus().ready) }
    var confirmingDelete by remember { mutableStateOf<StoredScenario?>(null) }

    // PM-9: a permission can be turned off while the app is in the background, and that is a
    // supported thing to do rather than an error. The answer is re-read, never remembered.
    LifecycleResumeEffect(Unit) {
        ready = context.readPermissionStatus().ready
        onPauseOrDispose {}
    }

    BaseScreen(
        viewModel = viewModel,
        title = stringResource(R.string.app_name),
        actions = {
            TextButton(onClick = onSetUp) { Text(stringResource(R.string.onboarding_reopen)) }
        },
        onEffect = { effect ->
            when (effect) {
                is ScenarioListEffect.OpenOverlay ->
                    if (!ready) {
                        onSetUp()
                    } else {
                        OverlayService.open(context, effect.scenarioId)
                        // OV-26: the whole point of the Overlay is that the user is somewhere
                        // else. Staying in front would put the floating control on top of the one
                        // application nobody wants to automate.
                        context.findActivity()?.moveTaskToBack(true)
                    }
            }
        },
    ) { state, padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            LazyColumn(
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 96.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxSize(),
            ) {
                if (!ready) {
                    item { SetUpCard(onSetUp) }
                }
                if (state.scenarios.isEmpty() && !state.loading) {
                    item { EmptyState() }
                }
                items(state.scenarios, key = { it.scenario.id }) { stored ->
                    ScenarioRow(
                        stored = stored,
                        onOpen = { viewModel.open(stored) },
                        onDelete = { confirmingDelete = stored },
                    )
                }
            }

            ExtendedFloatingActionButton(
                onClick = { viewModel.createScenario(context.getString(R.string.scenario_default_name)) },
                icon = { Icon(Icons.Default.Add, contentDescription = null) },
                text = { Text(stringResource(R.string.scenario_new)) },
                modifier = Modifier.align(Alignment.BottomEnd).padding(16.dp),
            )
        }
    }

    confirmingDelete?.let { target ->
        // Deleting a Scenario removes a directory of the user's own work, and there is no undo.
        AlertDialog(
            onDismissRequest = { confirmingDelete = null },
            title = { Text(stringResource(R.string.scenario_delete_title, target.scenario.name)) },
            text = { Text(stringResource(R.string.scenario_delete_body)) },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.delete(target)
                    confirmingDelete = null
                }) { Text(stringResource(R.string.scenario_delete)) }
            },
            dismissButton = {
                TextButton(onClick = { confirmingDelete = null }) {
                    Text(stringResource(R.string.step_cancel))
                }
            },
        )
    }
}

@Composable
private fun SetUpCard(onSetUp: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onSetUp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = stringResource(R.string.onboarding_not_ready),
                style = MaterialTheme.typography.titleSmall,
            )
            Text(
                text = stringResource(R.string.onboarding_intro),
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

/** An empty list is the first thing a new user sees, so it says what to do rather than "none". */
@Composable
private fun EmptyState() {
    Column(Modifier.fillMaxWidth().padding(vertical = 32.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.scenario_none_title), style = MaterialTheme.typography.titleMedium)
        Text(stringResource(R.string.scenario_none), style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun ScenarioRow(
    stored: StoredScenario,
    onOpen: () -> Unit,
    onDelete: () -> Unit,
) {
    Card(Modifier.fillMaxWidth().clickable(enabled = !stored.readOnly, onClick = onOpen)) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(start = 16.dp, top = 12.dp, bottom = 12.dp, end = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text(stored.scenario.name, style = MaterialTheme.typography.titleMedium)
                Text(
                    text =
                        if (stored.readOnly) {
                            // FS-14: it can still be deleted, because that is done on purpose.
                            stringResource(R.string.scenario_too_new)
                        } else {
                            pluralStringResource(
                                R.plurals.overlay_steps,
                                stored.scenario.steps.size,
                                stored.scenario.steps.size,
                            )
                        },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.padding(horizontal = 2.dp))
            IconButton(onClick = onDelete) {
                Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.scenario_delete))
            }
        }
    }
}

/** The Activity behind a Compose `LocalContext`, which is wrapped at least once by the theme. */
private tailrec fun Context.findActivity(): Activity? =
    when (this) {
        is Activity -> this
        is ContextWrapper -> baseContext.findActivity()
        else -> null
    }

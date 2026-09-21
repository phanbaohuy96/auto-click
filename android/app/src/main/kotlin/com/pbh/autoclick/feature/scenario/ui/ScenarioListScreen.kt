package com.pbh.autoclick.feature.scenario.ui

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.pbh.autoclick.R
import com.pbh.autoclick.core.ui.BaseScreen
import com.pbh.autoclick.domain.repository.StoredScenario
import com.pbh.autoclick.overlay.OverlayService
import com.pbh.autoclick.service.AccessibilityServiceState

/**
 * The Activity surface: manage Scenarios, and hand one to the Overlay.
 *
 * Nothing is authored here. Opening a Scenario starts [OverlayService] and the Activity has no
 * further part in it — [ADR-0015] on why the two surfaces are separate.
 */
@Composable
fun ScenarioListScreen(viewModel: ScenarioListViewModel = hiltViewModel()) {
    val context = LocalContext.current

    BaseScreen(
        viewModel = viewModel,
        title = stringResource(R.string.app_name),
        onEffect = { effect ->
            when (effect) {
                is ScenarioListEffect.OpenOverlay -> {
                    // A full onboarding flow is PM-1 to PM-11 and is not built yet. Until it is,
                    // a missing permission sends the user to the screen that grants it rather
                    // than starting an Overlay that cannot appear.
                    when {
                        !Settings.canDrawOverlays(context) ->
                            context.startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:${context.packageName}"),
                                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                            )

                        !AccessibilityServiceState.isEnabled(context) ->
                            context.startActivity(
                                Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                            )

                        else -> OverlayService.open(context, effect.scenarioId)
                    }
                }
            }
        },
    ) { state, padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            TextButton(
                onClick = { viewModel.createScenario(context.getString(R.string.scenario_default_name)) },
                modifier = Modifier.padding(horizontal = 16.dp),
            ) {
                Text(stringResource(R.string.scenario_new))
            }

            if (state.scenarios.isEmpty() && !state.loading) {
                Text(
                    text = stringResource(R.string.scenario_none),
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(16.dp),
                )
            }

            LazyColumn(
                contentPadding =
                    androidx.compose.foundation.layout
                        .PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(state.scenarios, key = { it.scenario.id }) { stored ->
                    ScenarioRow(
                        stored = stored,
                        onOpen = { viewModel.open(stored) },
                        onDelete = { viewModel.delete(stored) },
                    )
                }
            }
        }
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
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column {
                Text(stored.scenario.name, style = MaterialTheme.typography.titleMedium)
                Text(
                    text =
                        if (stored.readOnly) {
                            // FS-14: it can still be deleted, because that is done on purpose.
                            stringResource(R.string.scenario_too_new)
                        } else {
                            stringResource(R.string.scenario_step_count, stored.scenario.steps.size)
                        },
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            TextButton(onClick = onDelete) { Text(stringResource(R.string.scenario_delete)) }
        }
    }
}

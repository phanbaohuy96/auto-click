package com.pbh.autoclick.feature.scenario.ui

import androidx.lifecycle.viewModelScope
import com.pbh.autoclick.core.ui.BaseViewModel
import com.pbh.autoclick.core.ui.UiEffect
import com.pbh.autoclick.data.scenario.FileScenarioStore
import com.pbh.autoclick.domain.repository.StoredScenario
import com.pbh.autoclick.domain.scenario.Scenario
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import java.util.UUID
import javax.inject.Inject

data class ScenarioListUiState(
    val scenarios: List<StoredScenario> = emptyList(),
    val loading: Boolean = true,
)

sealed interface ScenarioListEffect : UiEffect {
    /** The Overlay is where a Scenario is authored and run, so opening one leaves the Activity. */
    data class OpenOverlay(
        val scenarioId: UUID,
    ) : ScenarioListEffect
}

@HiltViewModel
class ScenarioListViewModel
    @Inject
    constructor(
        private val store: FileScenarioStore,
    ) : BaseViewModel<ScenarioListUiState, ScenarioListEffect>(ScenarioListUiState()) {
        init {
            store
                .observeScenarios()
                .onEach { setState { copy(scenarios = it, loading = false) } }
                .launchIn(viewModelScope)
            launch { store.refresh() }
        }

        fun createScenario(name: String) {
            launch {
                val scenario = Scenario(name = name)
                store.save(scenario)
                sendEffect(ScenarioListEffect.OpenOverlay(scenario.id))
            }
        }

        fun open(scenario: StoredScenario) {
            // FS-14: a file this build cannot decode has no Steps, so there is nothing to open.
            if (!scenario.readOnly) sendEffect(ScenarioListEffect.OpenOverlay(scenario.scenario.id))
        }

        fun delete(scenario: StoredScenario) {
            launch { store.delete(scenario.scenario.id) }
        }

        /**
         * FS-15 again: renaming **is** saving, so there is no second step and no Save button.
         *
         * A blank name is refused rather than repaired. `SM-4`'s repair value exists for a file
         * that arrived damaged; a user emptying the field is asking a question, and the answer is
         * "a Scenario has to be called something", not a silent rewrite to "Untitled scenario".
         */
        fun rename(
            scenario: StoredScenario,
            name: String,
        ) {
            val trimmed = name.trim()
            if (scenario.readOnly || trimmed.isEmpty()) return
            launch { store.save(scenario.scenario.copy(name = trimmed)) }
        }

        /** FS-3: a copy of the whole directory, Templates included (`RC-27`). */
        fun duplicate(scenario: StoredScenario) {
            if (scenario.readOnly) return
            launch { store.duplicate(scenario.scenario.id) }
        }
    }

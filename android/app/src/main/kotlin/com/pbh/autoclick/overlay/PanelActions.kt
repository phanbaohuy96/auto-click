package com.pbh.autoclick.overlay

import com.pbh.autoclick.domain.scenario.Scenario
import com.pbh.autoclick.overlay.ui.ScenarioPanelActions
import com.pbh.autoclick.overlay.ui.StepPanelActions

/** What the panel's two faces do, wired to the service and to the Overlay's own state. */
internal fun stepPanelActions(
    editing: EditingStep,
    callbacks: OverlayCallbacks,
    update: ((OverlayUiState) -> OverlayUiState) -> Unit,
): StepPanelActions =
    StepPanelActions(
        onDraftChanged = { draft -> update { it.withStep { open -> open.copy(step = open.step.copy(draft = draft)) } } },
        onTypingChanged = { typing -> update { it.withPanelTyping(typing) } },
        onSave = { callbacks.onStepSaved(editing.draft) },
        onCancel = { update { it.copy(panel = null) } },
        onDelete = { callbacks.onStepDeleted(editing.draft.stepId) },
        onMove = { by -> callbacks.onStepMoved(editing.draft.stepId, by) },
        onGo = { by -> callbacks.onStepNavigated(editing.draft.stepId, by) },
    )

/** FS-15: every one of these is the edit and the save at once — there is no Save for a Scenario. */
internal fun scenarioPanelActions(
    scenario: Scenario,
    callbacks: OverlayCallbacks,
    update: ((OverlayUiState) -> OverlayUiState) -> Unit,
): ScenarioPanelActions =
    ScenarioPanelActions(
        onRenamed = { callbacks.onScenarioChanged(scenario.copy(name = it)) },
        onRunCountChanged = { callbacks.onScenarioChanged(scenario.copy(runCount = it)) },
        onCountdownChanged = { callbacks.onScenarioChanged(scenario.copy(countdownMilliseconds = it)) },
        onTypingChanged = { typing -> update { it.withPanelTyping(typing) } },
        onAddStep = callbacks::onAddStep,
        onOpenStep = callbacks::onStepOpened,
        onMoveStep = callbacks::onStepMoved,
        onDeleteStep = callbacks::onStepDeleted,
        onFreeTheTouch = callbacks::onFreeTheTouch,
        onOpenApp = callbacks::onOpenApp,
        onCloseOverlay = callbacks::onCloseOverlay,
        onDismiss = { update { it.copy(panel = null) } },
    )

internal fun OverlayUiState.withStep(edit: (PanelState.StepEditor) -> PanelState.StepEditor): OverlayUiState =
    copy(panel = (panel as? PanelState.StepEditor)?.let(edit) ?: panel)

internal fun OverlayUiState.withPanelTyping(typing: Boolean): OverlayUiState =
    copy(
        panel =
            when (val open = panel) {
                is PanelState.StepEditor -> open.copy(typing = typing)
                is PanelState.ScenarioEditor -> open.copy(typing = typing)
                null -> null
            },
    )

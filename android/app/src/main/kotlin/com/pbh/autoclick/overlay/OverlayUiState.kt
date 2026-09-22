package com.pbh.autoclick.overlay

import com.pbh.autoclick.domain.editor.StepDraft
import com.pbh.autoclick.domain.editor.toStep
import com.pbh.autoclick.domain.editor.violations
import com.pbh.autoclick.domain.overlay.Marker
import com.pbh.autoclick.domain.run.FinishReason
import com.pbh.autoclick.domain.scenario.GestureLimits
import com.pbh.autoclick.domain.scenario.Scenario
import com.pbh.autoclick.domain.scenario.ScreenProfile
import com.pbh.autoclick.domain.scenario.Step
import com.pbh.autoclick.domain.scenario.StepViolation
import java.util.UUID

/**
 * What the Overlay is showing, in one value.
 *
 * The floating control has exactly two shapes (`OV-12`), and which one it wears is decided here
 * rather than by whoever last called a setter.
 */
data class OverlayUiState(
    /**
     * The Scenario as last saved, or null before one is open.
     *
     * Held here rather than beside the state because four things read it — the Markers, both
     * halves of the panel, the control's caption and the notification — and two copies of the
     * same truth is how a Marker ends up somewhere the Scenario does not agree with.
     */
    val scenario: Scenario? = null,
    val markers: List<Marker> = emptyList(),
    val run: RunState = RunState.Stopped,
    /** OV-17: why the last run ended, shown where the user is already looking. */
    val lastFinish: FinishReason? = null,
    val collapsed: Boolean = false,
    /** OV-21, OV-28: what the one panel window is showing, or null when it is closed. */
    val panel: PanelState? = null,
    /** RD-1: the session in progress, or null when nothing is being recorded. */
    val recording: RecordingSession? = null,
    /**
     * The Screen profile this Scenario's coordinates are measured against (`SM-14`), once it has
     * one.
     *
     * Markers are clamped into **this** rather than into the screen in front of the user, so that
     * dragging and `SM-17` agree about where the edge is. A phone rotated after the Scenario was
     * built would otherwise let a Marker be dragged to a point the Scenario itself calls
     * off-screen.
     */
    val authoringProfile: ScreenProfile? = null,
) {
    val scenarioName: String get() = scenario?.name.orEmpty()

    val stepCount: Int get() = scenario?.steps?.size ?: 0

    /** Anything at all in flight: counting down, walking Steps, or finishing a stroke. */
    val running: Boolean get() = run !is RunState.Stopped

    /** RD-1: recording, like running, is a state in which the editor has to be out of the way. */
    val isRecording: Boolean get() = recording != null

    /**
     * OV-11, RD-1: Markers would be tapped by the very Gestures they describe — and, while
     * recording, they would swallow the touches meant for the application underneath.
     */
    val showMarkers: Boolean get() = !running && !isRecording

    /**
     * OV-20: the panel is open only while nothing is running.
     *
     * Derived rather than set, and that is the point. The panel is the one window allowed to take
     * input focus, so "it is closed before a run starts" has to be a property of the state and not
     * a call somebody remembers to make. A `setText` Step therefore never has this window to find.
     */
    val showPanel: Boolean get() = panel != null && !running && !isRecording

    /** OV-20: the window drops FLAG_NOT_FOCUSABLE only while a field in it holds the caret. */
    val typing: Boolean get() = showPanel && panel?.typing == true

    /** The Step open in the panel, if the panel is showing a Step at all. */
    val editing: EditingStep? get() = (panel as? PanelState.StepEditor)?.step

    /** Which Marker the panel is about, so the Marker layer can say which one it is (`OV-21`). */
    val editedStepId: UUID? get() = editing?.draft?.stepId.takeIf { showPanel }

    sealed interface RunState {
        data object Stopped : RunState

        /** OV-16: shown in the control, counting down, cancelled by the same Stop. */
        data class CountingDown(
            val remainingMilliseconds: Int,
        ) : RunState

        data class Running(
            val stepNumber: Int,
            val stepCount: Int,
        ) : RunState

        /** GX-8: a stroke is still in flight and is allowed to finish. */
        data object Stopping : RunState
    }
}

/**
 * A recording session in progress (`RD-1`).
 *
 * [listening] is false only for the moment a recorded touch is being handed back to the
 * application underneath (`RD-5`). The layer has to stop taking touches for exactly that long, or
 * it records its own re-emission and the session never ends.
 */
data class RecordingSession(
    val touches: Int = 0,
    val listening: Boolean = true,
)

/**
 * The two things the panel window can be showing (OV-21, OV-28).
 *
 * One window rather than two, because they want the same place on the screen, they want the same
 * one exception to `OV-3`, and two of them open at once has no meaning. Making that a sealed type
 * rather than two nullable fields is what stops the pair drifting apart.
 */
sealed interface PanelState {
    /** OV-20: true only while a field in the panel holds the caret. */
    val typing: Boolean

    /** OV-28: the Scenario as a whole — its name, how often it runs, and its Steps in order. */
    data class ScenarioEditor(
        override val typing: Boolean = false,
    ) : PanelState

    data class StepEditor(
        val step: EditingStep,
        override val typing: Boolean = false,
    ) : PanelState
}

/**
 * One Step open in the Step panel, with everything the panel needs to judge it (OV-21, OV-22).
 *
 * [limits] travels with the draft because they are the platform's, read from the connected
 * service (`SM-17`), and a panel that judged a Step against the defaults would let a Step through
 * on a device whose limits are lower — which is a Step that silently does nothing.
 */
data class EditingStep(
    val draft: StepDraft,
    /** The Step as saved, so the panel can tell whether there is anything to lose (`OV-24`). */
    val original: Step,
    /** OV-6: counting from 1, as the Marker shows it. */
    val stepNumber: Int,
    val stepCount: Int,
    val limits: GestureLimits = GestureLimits(),
    val profile: ScreenProfile? = null,
) {
    /** SM-17: every reason this cannot be saved, all of them at once. */
    val violations: List<StepViolation> get() = draft.violations(limits, profile)

    /** OV-22: Save is offered only when there is nothing wrong to save. */
    val canSave: Boolean get() = violations.isEmpty()

    val canMoveUp: Boolean get() = stepNumber > 1

    val canMoveDown: Boolean get() = stepNumber < stepCount

    /** Whether Save would change anything. Moving a Step does not, so it stays available. */
    val isDirty: Boolean get() = draft.toStep() != original

    /**
     * OV-24: walking to the next Step is refused while there are unsaved edits.
     *
     * Refused rather than silently discarding or silently saving. Both of those are guesses about
     * what the user meant, and Save and Cancel are already on screen to be asked.
     */
    val canGoBack: Boolean get() = stepNumber > 1 && !isDirty

    val canGoForward: Boolean get() = stepNumber < stepCount && !isDirty
}

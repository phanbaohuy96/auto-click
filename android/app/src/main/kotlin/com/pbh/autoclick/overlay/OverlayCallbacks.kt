package com.pbh.autoclick.overlay

import com.pbh.autoclick.domain.editor.StepDraft
import com.pbh.autoclick.domain.overlay.Marker
import com.pbh.autoclick.domain.scenario.Scenario
import com.pbh.autoclick.domain.scenario.ScreenPoint
import com.pbh.autoclick.overlay.ui.RecordingEvent
import java.util.UUID

/**
 * What the Overlay asks the service to do. Nothing in the Overlay decides anything by itself.
 *
 * Four interfaces rather than one list of eighteen methods, because they answer to four different
 * parts of the specification and change for four different reasons: running a Scenario (`GX-*`),
 * recording one (`RD-*`), editing one (`SM-*`, `OV-21` to `OV-28`), and the Overlay's own
 * existence (`OV-14`, `OV-30`).
 */
interface OverlayCallbacks :
    RunCallbacks,
    RecordCallbacks,
    EditCallbacks,
    ShellCallbacks

/** GX-7, GX-8, GX-11: starting, stopping, and the one recovery that is not either. */
interface RunCallbacks {
    fun onStart()

    fun onStop()

    fun onFreeTheTouch()
}

/** RD-1 to RD-8: recording a session of real touches and turning it into Steps. */
interface RecordCallbacks {
    fun onRecord()

    fun onStopRecording()

    /** RD-2: one touch event, with Android's `MotionEvent` left at the boundary. */
    fun onRecordingEvent(event: RecordingEvent)
}

/** Everything that changes the open Scenario. Each of these is written to disk at once (`FS-15`). */
interface EditCallbacks {
    fun onAddStep()

    fun onMarkerMoved(
        marker: Marker,
        to: ScreenPoint,
    )

    /** OV-7: a Marker is placed by dragging and configured by tapping. This is the tap. */
    fun onMarkerTapped(marker: Marker)

    /** OV-28: opens the panel on one named Step, whether or not it draws a Marker. */
    fun onStepOpened(stepId: UUID)

    /** OV-22: only ever called with a draft that has no violations left. */
    fun onStepSaved(draft: StepDraft)

    fun onStepDeleted(stepId: UUID)

    /** OV-6: renumbers this Marker and its neighbours', and is applied at once. */
    fun onStepMoved(
        stepId: UUID,
        by: Int,
    )

    /** OV-24: opens the panel on the Step [by] places away in the Scenario. */
    fun onStepNavigated(
        stepId: UUID,
        by: Int,
    )

    /** OV-28: the Scenario's own fields — its name, how often it runs, its countdown. */
    fun onScenarioChanged(scenario: Scenario)
}

/** The Overlay as a thing on the screen, rather than as an editor. */
interface ShellCallbacks {
    /** OV-14: where the control was let go of, so the next launch can put it back there. */
    fun onControlMoved(at: ScreenPoint)

    /** OV-30: bring the Activity back. */
    fun onOpenApp()

    /** OV-30: take the Overlay away entirely. */
    fun onCloseOverlay()
}

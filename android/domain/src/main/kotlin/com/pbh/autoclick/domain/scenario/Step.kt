package com.pbh.autoclick.domain.scenario

import java.util.UUID

/**
 * One Action at one Target, repeated [repeatCount] times, followed by [delayMillisecondsAfter]
 * (SM-5).
 *
 * Nothing is clamped here. SM-16 clamps on the way in from disk and the editor refuses out-of-range
 * values outright, which keeps this a plain value and keeps `copy()` honest.
 */
data class Step(
    val id: UUID = UUID.randomUUID(),
    val action: StepAction,
    val target: StepTarget,
    val repeatCount: Int = 1,
    val delayMillisecondsAfter: Int = ScenarioLimits.DEFAULT_DELAY_MILLISECONDS,
) {
    /** SM-8: a Step whose Action ignores its Target draws no Marker. */
    val hasMarker: Boolean get() = action.usesTarget

    /** Every point this Step touches, so a Screen profile check has something to walk. */
    val points: List<ScreenPoint>
        get() =
            when (val current = action) {
                is StepAction.Tap -> listOf(target.point)
                is StepAction.Swipe -> listOf(target.point, current.destination)
                is StepAction.MultiTouch -> current.paths.flatMap { listOf(it.start, it.end) }
                is StepAction.Global, is StepAction.SetText -> emptyList()
            }
}

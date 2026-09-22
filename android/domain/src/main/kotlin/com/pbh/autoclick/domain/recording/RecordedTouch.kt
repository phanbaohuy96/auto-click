package com.pbh.autoclick.domain.recording

import com.pbh.autoclick.domain.scenario.GestureLimits
import com.pbh.autoclick.domain.scenario.ScenarioLimits
import com.pbh.autoclick.domain.scenario.ScenarioLimits.clampedTo
import com.pbh.autoclick.domain.scenario.ScreenPoint
import com.pbh.autoclick.domain.scenario.Step
import com.pbh.autoclick.domain.scenario.StepAction
import com.pbh.autoclick.domain.scenario.StepTarget
import kotlin.math.abs
import kotlin.math.max

/**
 * One finger, from the moment it touched the screen to the moment it left (`RD-2`).
 *
 * Deliberately without Android in it: turning touches into **Step**s is arithmetic about time and
 * distance, it is the part of recording that decides what the user ends up with, and it is
 * therefore the part tested on the JVM rather than by hand on a phone.
 */
data class RecordedTouch(
    val start: ScreenPoint,
    val end: ScreenPoint,
    /** How long the finger was down. Becomes a hold, or a swipe's travel time. */
    val durationMilliseconds: Long,
    /** How long the screen was untouched before this one began. */
    val gapBeforeMilliseconds: Long,
)

/**
 * The **Step**s a recording session produces (`RD-3`, `RD-4`).
 *
 * Two rules, and both exist because of what the user actually did rather than what would be tidy:
 *
 * - A finger that stayed put is a `tap` and keeps **how long it was held**; one that travelled is a
 *   `swipe` and keeps **how long it took**. `ADR-0004`'s principle, in Android's vocabulary: a
 *   recording keeps real timing rather than normalising it.
 * - The pause **before** each touch becomes the previous **Step**'s delay. Waiting is something
 *   the user did between two actions, so it belongs to the gap and not to either end of it — and
 *   the wait before the *first* touch is discarded, because that one is only somebody finding
 *   their aim.
 *
 * [slopPixels] is the platform's own idea of how far a finger may wander and still be a tap. It is
 * passed in rather than assumed, for the same reason [GestureLimits] is.
 */
fun List<RecordedTouch>.toSteps(
    limits: GestureLimits = GestureLimits(),
    slopPixels: Int = DEFAULT_SLOP_PIXELS,
): List<Step> =
    mapIndexed { index, touch ->
        Step(
            action = touch.toAction(limits, slopPixels),
            target = StepTarget(touch.start),
            delayMillisecondsAfter = delayAfter(index),
        )
    }

private fun List<RecordedTouch>.delayAfter(index: Int): Int =
    getOrNull(index + 1)
        ?.gapBeforeMilliseconds
        ?.coerceAtMost(Int.MAX_VALUE.toLong())
        ?.toInt()
        ?.clampedTo(ScenarioLimits.delayMilliseconds)
        ?: ScenarioLimits.DEFAULT_DELAY_MILLISECONDS

private fun RecordedTouch.toAction(
    limits: GestureLimits,
    slopPixels: Int,
): StepAction {
    val travel = max(abs(end.x - start.x), abs(end.y - start.y))
    val held = durationMilliseconds.coerceIn(0L, limits.maxGestureDurationMilliseconds)
    return if (travel <= slopPixels) {
        StepAction.Tap(holdMilliseconds = held)
    } else {
        // A swipe of no duration is one the platform rejects, and a rejected Gesture is a Step
        // that silently does nothing (GX-13).
        StepAction.Swipe(destination = end, durationMilliseconds = held.coerceAtLeast(1L))
    }
}

/**
 * What Android's `ViewConfiguration` reports on a typical phone, for callers with no view to ask.
 *
 * Only tests and defaults use it. The Overlay passes the real number.
 */
const val DEFAULT_SLOP_PIXELS = 24

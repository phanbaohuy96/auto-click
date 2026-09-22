package com.pbh.autoclick.overlay

import com.pbh.autoclick.domain.recording.RecordedTouch
import com.pbh.autoclick.domain.run.Gesture
import com.pbh.autoclick.domain.run.GestureDispatcher
import com.pbh.autoclick.domain.run.Stroke
import com.pbh.autoclick.domain.scenario.ScreenPoint
import com.pbh.autoclick.overlay.ui.RecordingEvent

/**
 * Turns what the recording layer saw into [RecordedTouch]es, and hands each one back to the
 * application underneath (`RD-2`, `RD-5`).
 *
 * Holds the one piece of state recording has — the finger currently down — and nothing else. What
 * the touches *mean* is `domain/recording`, which is where it can be tested.
 */
class Recorder(
    private val dispatcher: GestureDispatcher,
    /** Told when a touch is complete, so the Overlay can count it and the caller can re-emit it. */
    private val onRecorded: (RecordedTouch) -> Unit,
) {
    private var down: Down? = null

    /** When the screen was last let go of, so the next touch knows how long the pause was. */
    private var lastReleasedAt: Long? = null

    val touches = mutableListOf<RecordedTouch>()

    private data class Down(
        val at: ScreenPoint,
        val atMilliseconds: Long,
        var latest: ScreenPoint,
    )

    /** Returns the Gesture to re-emit, or null when nothing has finished. */
    fun accept(event: RecordingEvent): Gesture? =
        when (event) {
            is RecordingEvent.Down -> {
                down = Down(at = event.at, atMilliseconds = event.atMilliseconds, latest = event.at)
                null
            }

            is RecordingEvent.Moved -> {
                down?.latest = event.at
                null
            }

            RecordingEvent.Cancelled -> {
                // The system took the gesture away. Half a touch is not a Step, and re-emitting
                // one the user did not complete would put something on screen they never did.
                down = null
                null
            }

            is RecordingEvent.Up -> complete(event)
        }

    private fun complete(event: RecordingEvent.Up): Gesture? {
        val started = down ?: return null
        down = null
        val duration = (event.atMilliseconds - started.atMilliseconds).coerceAtLeast(0)
        val gap = lastReleasedAt?.let { (started.atMilliseconds - it).coerceAtLeast(0) } ?: 0L
        lastReleasedAt = event.atMilliseconds

        val touch =
            RecordedTouch(
                start = started.at,
                end = event.at,
                durationMilliseconds = duration,
                gapBeforeMilliseconds = gap,
            )
        touches += touch
        onRecorded(touch)

        // RD-5: the same movement, at the same speed, handed to whatever is underneath. A stroke
        // of no duration is refused by the platform (GX-13), so the shortest one is a millisecond.
        return Gesture(
            listOf(Stroke(from = touch.start, to = touch.end, durationMilliseconds = duration.coerceAtLeast(1L))),
        )
    }

    suspend fun replay(gesture: Gesture) {
        dispatcher.dispatch(gesture)
    }
}

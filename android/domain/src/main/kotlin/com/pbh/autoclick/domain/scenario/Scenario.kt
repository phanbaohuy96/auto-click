package com.pbh.autoclick.domain.scenario

import java.util.UUID

/**
 * An ordered sequence of Steps, and the screen they were measured against (SM-1).
 *
 * [screenProfile] is null only while the Scenario has no Step with a point in it: SM-14 says the
 * profile is captured when the first Marker is placed, and an empty Scenario has not reached that
 * moment yet.
 */
data class Scenario(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val steps: List<Step> = emptyList(),
    val runCount: RunCount = RunCount.Times(1),
    val countdownMilliseconds: Int = ScenarioLimits.DEFAULT_COUNTDOWN_MILLISECONDS,
    val screenProfile: ScreenProfile? = null,
) {
    /** SM-8: how many Markers the Overlay draws for this Scenario. */
    val markerCount: Int get() = steps.count { it.hasMarker }

    companion object {
        /**
         * The name given to a Scenario whose scenario.json has none (SM-4).
         *
         * Deliberately **not** translated: it is a repair value, not a name the user chose, and it
         * is written back on the next save. Translating it would let an interface setting rewrite
         * user data, and would give the same damaged file a different name on every phone.
         */
        const val REPAIRED_NAME = "Untitled scenario"
    }
}

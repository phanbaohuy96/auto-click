package com.pbh.autoclick.overlay.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.pbh.autoclick.R
import com.pbh.autoclick.domain.scenario.Step
import com.pbh.autoclick.domain.scenario.StepAction

/**
 * One line saying what a Step does, for the Scenario panel's list (`OV-28`).
 *
 * Coordinates are in it because they are the only thing that tells two otherwise identical taps
 * apart, and because a list of fifteen rows all reading "Tap" would be worse than no list.
 */
@Composable
internal fun Step.summary(): String {
    val body =
        when (val current = action) {
            is StepAction.Tap -> stringResource(R.string.summary_tap, target.point.x, target.point.y)

            is StepAction.Swipe ->
                stringResource(
                    R.string.summary_swipe,
                    target.point.x,
                    target.point.y,
                    current.destination.x,
                    current.destination.y,
                )

            is StepAction.MultiTouch -> stringResource(R.string.summary_multi_touch, current.paths.size)
            is StepAction.Global -> current.action.label()
            is StepAction.SetText -> stringResource(R.string.summary_set_text, current.text)
        }
    return if (repeatCount > 1) stringResource(R.string.summary_repeated, body, repeatCount) else body
}

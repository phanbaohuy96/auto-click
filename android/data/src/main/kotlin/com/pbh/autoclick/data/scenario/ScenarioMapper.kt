package com.pbh.autoclick.data.scenario

import com.pbh.autoclick.domain.repository.StoredScenario
import com.pbh.autoclick.domain.scenario.RunCount
import com.pbh.autoclick.domain.scenario.Scenario
import com.pbh.autoclick.domain.scenario.ScreenPoint
import com.pbh.autoclick.domain.scenario.ScreenProfile
import com.pbh.autoclick.domain.scenario.ScreenRotation
import com.pbh.autoclick.domain.scenario.Step
import com.pbh.autoclick.domain.scenario.StepAction
import com.pbh.autoclick.domain.scenario.StepTarget
import com.pbh.autoclick.domain.scenario.clampedToLimits
import java.util.UUID

/**
 * Between the file format and the model, in both directions.
 *
 * Reading is the forgiving direction (FS-12): a missing field takes its default, an unreadable id
 * becomes a fresh one, an unknown enum name falls back rather than throwing. Writing is the exact
 * direction — what comes out is what the specification describes.
 */
internal fun ScenarioDto.toDomain(): Scenario =
    Scenario(
        id = id.toUuidOrRandom(),
        name = name.ifBlank { Scenario.REPAIRED_NAME },
        steps = steps.map { it.toDomain() },
        runCount = repeat.toDomain(),
        countdownMilliseconds = countdownMilliseconds,
        screenProfile = screenProfile?.toDomain(),
    ).clampedToLimits()

internal fun Scenario.toDto(): ScenarioDto =
    ScenarioDto(
        schemaVersion = StoredScenario.CURRENT_SCHEMA_VERSION,
        id = id.toString(),
        name = name,
        repeat = runCount.toDto(),
        countdownMilliseconds = countdownMilliseconds,
        screenProfile = screenProfile?.toDto(),
        steps = steps.map { it.toDto() },
    )

private fun RepeatDto.toDomain(): RunCount =
    when (this) {
        is RepeatDto.Count -> RunCount.Times(value)
        RepeatDto.UntilStopped -> RunCount.UntilStopped
    }

private fun RunCount.toDto(): RepeatDto =
    when (this) {
        is RunCount.Times -> RepeatDto.Count(count)
        RunCount.UntilStopped -> RepeatDto.UntilStopped
    }

private fun ScreenProfileDto.toDomain(): ScreenProfile =
    ScreenProfile(
        widthPixels = widthPixels,
        heightPixels = heightPixels,
        densityDpi = densityDpi,
        rotation =
            ScreenRotation.entries.firstOrNull { it.name == rotation }
                ?: ScreenRotation.PORTRAIT,
    )

private fun ScreenProfile.toDto(): ScreenProfileDto =
    ScreenProfileDto(
        widthPixels = widthPixels,
        heightPixels = heightPixels,
        densityDpi = densityDpi,
        rotation = rotation.name,
    )

private fun StepDto.toDomain(): Step =
    Step(
        id = id.toUuidOrRandom(),
        action = action.toDomain(),
        target = StepTarget(ScreenPoint(target.x(), target.y())),
        repeatCount = repeat,
        delayMillisecondsAfter = delayMillisecondsAfter,
    )

private fun Step.toDto(): StepDto =
    StepDto(
        id = id.toString(),
        action = action.toDto(),
        target = TargetDto.Point(x = target.point.x, y = target.point.y),
        repeat = repeatCount,
        delayMillisecondsAfter = delayMillisecondsAfter,
    )

private fun String.toUuidOrRandom(): UUID = runCatching { UUID.fromString(this) }.getOrElse { UUID.randomUUID() }

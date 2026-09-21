package com.pbh.autoclick.core.ui

import com.pbh.autoclick.core.R
import com.pbh.autoclick.domain.model.DomainError

/**
 * Central error-to-text policy — the single place that turns a [DomainError] into a localized
 * [UiText]. One exhaustive `when` instead of a per-feature copy. Features may still map a specific
 * error to a bespoke message where the interface warrants it, but this is the default every screen
 * falls back to.
 */
fun DomainError.toUiText(): UiText =
    when (this) {
        DomainError.Unknown -> UiText.Resource(R.string.core_error_generic)
    }

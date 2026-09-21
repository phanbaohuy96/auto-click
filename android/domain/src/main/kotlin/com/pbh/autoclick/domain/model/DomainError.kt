package com.pbh.autoclick.domain.model

/**
 * Typed failure reasons shared by domain, data and UI translation layers.
 *
 * Deliberately almost empty. The template arrived with a network- and auth-shaped taxonomy —
 * `Unauthorized`, `Offline`, `Remote(code)`, email and password validation — and Auto Click has no
 * server, no account and no network permission, so none of it described a failure this app can
 * actually have. The real cases (a permission not granted, a Screen profile that does not match, a
 * Target that never resolved, a scenario.json this build cannot read) are defined with slice A1,
 * where they can carry requirement numbers instead of being guessed at here.
 */
sealed interface DomainError {
    /** Fallback for unexpected failures that should still be shown safely. */
    data object Unknown : DomainError
}

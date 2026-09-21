# Auto Click

Automate repetitive work by emitting synthetic input: an ordered sequence of operations, each one
an **Action** paired with a **Target**, recorded or built by hand and replayed on demand.

One product, two platforms. The concepts are shared; almost nothing else is.

| | |
|---|---|
| [**macos/**](macos/README.md) | A menu-bar app for macOS 14+. Shipping. |
| [**android/**](android/README.md) | An accessibility-service app for Android 11+. In specification. |

## Where to read what

| Document | Answers |
|---|---|
| [`CONTEXT-MAP.md`](CONTEXT-MAP.md) | Which glossary covers which platform |
| [`CONTEXT.md`](CONTEXT.md) | The shared language — what the concepts are called and what they mean |
| [`docs/adr/`](docs/adr/) | Why this option was chosen over that one, for the product as a whole |
| [`docs/sdd/`](docs/sdd/) | The purpose the whole product answers to, and the macOS specification |
| [`android/docs/`](android/docs/) | The Android glossary, specification, decisions, market survey and test plan |

The specification comes **before** the code, on both platforms. Every observable behaviour appears
in an `sdd/` document as a numbered requirement, and the code cites that number wherever the
behaviour is not obvious. Change a behaviour and you change the spec first.

Decision records are numbered in **one sequence** across the product; the folder says which context
a decision belongs to. `docs/adr/0001`–`0011` are shared and macOS-era, `android/docs/adr/0012`
onwards are Android's.

## Paths

Commands in `macos/README.md` run from `macos/`. Paths named inside `docs/sdd/` and `docs/adr/`
— `Sources/`, `Resources/`, `Package.swift`, `scripts/` — are relative to `macos/` as well; they
were written when that was the repository root.

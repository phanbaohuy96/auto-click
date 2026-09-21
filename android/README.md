# Auto Click for Android

The Android member of Auto Click. See the [repository README](../README.md) for the product, and
[`../CONTEXT.md`](../CONTEXT.md) for the shared language.

**Status: slice A1, mostly built.** The app installs, lists Scenarios, draws its **Marker**s over
whatever is in front, drags them, and runs a **Scenario** through the accessibility service. What
is missing is the **Step** editor — tapping a **Marker** cannot yet change what its **Step** does —
and the onboarding flow, so permissions are granted by being sent to the right Settings screen
rather than being explained first.

| Built | Not built yet |
|---|---|
| **Scenario / Step / Action × Target**, limits, validation ([03](docs/sdd/03-scenario-model.md)) | The **Step** panel: tap a **Marker** to configure it ([06](docs/sdd/06-overlay-and-markers.md)) |
| One directory per **Scenario** on disk ([04](docs/sdd/04-storage.md)) | Onboarding, including the Android 13 wall ([02](docs/sdd/02-permissions-and-onboarding.md)) |
| The runner, and every exit path releasing ([05](docs/sdd/05-gesture-execution.md)) | Adding a **Step** from the floating control |
| The **Overlay**, **Marker**s and the floating control ([06](docs/sdd/06-overlay-and-markers.md)) | Recording (A2), recognition (A3), languages (A4) |

## Where to read what

| Document | Answers |
|---|---|
| [`CONTEXT.md`](CONTEXT.md) | The terms that exist only on Android — **Overlay**, **Marker**, **Gesture**, **Screen profile** |
| [`docs/sdd/`](docs/sdd/README.md) | The specification, and the requirement-identifier convention |
| [`docs/sdd/01-scope.md`](docs/sdd/01-scope.md) | The four slices, and what is deliberately out of scope |
| [`docs/sdd/02-permissions-and-onboarding.md`](docs/sdd/02-permissions-and-onboarding.md) | Why onboarding has to walk the user into a wall on purpose |
| [`docs/sdd/03-scenario-model.md`](docs/sdd/03-scenario-model.md) | The five **Action**s, the one **Target**, and which limits Android owns |
| [`docs/sdd/04-storage.md`](docs/sdd/04-storage.md) | What `scenario.json` looks like, and what happens when it is wrong |
| [`docs/sdd/05-gesture-execution.md`](docs/sdd/05-gesture-execution.md) | What happens when the user presses Stop, and why that is most of the code |
| [`docs/adr/`](docs/adr/) | Android decisions, numbered from 0012 in the product-wide sequence |
| [`docs/landscape.md`](docs/landscape.md) | What the competing apps do, what users punish them for, and our answers |
| [`docs/testing.md`](docs/testing.md) | Three tiers, and what is honestly not verified yet |

## What this project is built on, and what it dropped

Started from `android-base-structure`: Kotlin, Compose, Material 3, MVVM with unidirectional data
flow, Hilt, Navigation Compose, and the Spotless / ktlint / detekt / Kover toolchain.

Removed on purpose, so the absences are not read as oversights:

- **Room** — a **Scenario** is a directory of files, [ADR-0014](docs/adr/0014-no-database.md).
- **Retrofit, OkHttp, the `INTERNET` permission and the network security config** — Auto Click talks
  to no server at all.
- **The `dev`/`staging`/`prod` flavours** — they existed to point at three base URLs.
- **The reference login and item features**, and the network- and auth-shaped `DomainError`
  taxonomy that came with them. The failure cases this app really has are defined with slice A1.
- **`BaseScreen` for the main surface.** It assumes an Activity, and most of this app's interface
  lives in the **Overlay**, which is not one — [ADR-0015](docs/adr/0015-compose-in-the-overlay.md).
  `BaseScreen` stays for the Activity screens; `BaseOverlayScreen` joins it in `:core` at A1.

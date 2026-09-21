# Testing — three tiers, and an honest gap

macOS cannot test the thing it exists to do. `README.md` says why: *"Accessibility and Screen
Recording can only be granted to a signed bundle, never to SwiftPM's test binary, so every seam that
touches the operating system is replaced by a fake."* Hence 58 KB of
[`manual-e2e-tests.md`](../../docs/manual-e2e-tests.md).

Android is not stuck that way, and the difference is worth spending.

## Tier 1 — JVM unit tests, no device

Everything in `:domain`, which is pure Kotlin: the **Scenario** model, clamping and repair on load,
the runner's ordering and timing, **Guard** evaluation, **Screen profile** comparison, and template
matching. `TemplateMatcher` and `GrayImage` are arithmetic over pixel arrays — ported to Kotlin they
are testable against fixture bitmaps with no emulator at all, including the two-scale behaviour of
[ADR-0008](../../docs/adr/0008-match-templates-at-two-scales.md).

## Tier 2 — Instrumented tests on an emulator, against a target app

The tier macOS cannot have. On an emulator the permissions are scriptable:

- `adb shell settings put secure enabled_accessibility_services …` enables the service
- `adb shell appops set … SYSTEM_ALERT_WINDOW allow` grants the **Overlay**

and a **target app** — a debug-only app whose whole job is to record which touches arrived, where,
and when — turns "did the tap land" into an assertion instead of a paragraph in a manual.

What this tier is for, in order of importance:

1. **Every stroke is terminated, on every exit.** Dispatch a continuing swipe, kill the runner
   mid-stroke, and assert the target app saw the finger lift. Then again for Stop, for an error, for
   coroutine cancellation, and for the service being disconnected. This is `SF-1` in Android's
   vocabulary and the category's worst bug (`landscape.md`, pain 1) — checked on every commit.
2. **Order and speed.** A 15-**Step** sequence arrives in the right order, with gaps short enough to
   serve the *speed* pressure rather than merely eventually.
3. **Coordinates.** A **Marker** at a pixel produces a touch at that pixel, and a **Screen profile**
   mismatch produces no touch at all.

## Tier 3 — By hand, on real hardware

Reserved for what an emulator misrepresents. Declared rather than skipped, because a gap that is
written down can be planned around and a gap that is not gets mistaken for coverage.

**Currently unverified — no physical Android device is in use on this project.** Everything below is
untested until one is:

- The **latched-touch freeze** itself, and whether cycling the accessibility service clears it. The
  whole value of the one-tap *free the touch* recovery rests on this, and it is a promise that must
  not be made in the interface until it has been seen to work on a phone.
- Vendor power optimisers — Samsung One UI sleep, MIUI, and their habit of stopping a service that
  looks idle. Reported as a cause of silent death across the category.
- Skin-specific **Overlay** restrictions.
- Real touch latency and how a game reacts to a synthetic touch arriving beside a real one.
- Whether an application detects the accessibility service and refuses to run.

## Not automated on purpose

Driving the system permission dialogs with UiAutomator. The dialogs change wording and layout
between Android versions, so those tests break when Google edits a label rather than when this code
is wrong — the most brittle coverage available, bought at the highest maintenance price.

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

- `adb shell appops set … ACCESS_RESTRICTED_SETTINGS allow` — **first**, or the next line is
  silently reverted. A sideloaded build is behind the restricted-settings wall (`PM-1`…`PM-11`),
  and the platform does not report the refusal: `settings put` appears to succeed and
  `settings get` returns `null`.
- `adb shell settings put secure enabled_accessibility_services …` enables the service
- `adb shell settings put secure accessibility_enabled 1`
- `adb shell appops set … SYSTEM_ALERT_WINDOW allow` grants the **Overlay**

and a **target app** — a debug-only app whose whole job is to record which touches arrived, where,
and when — turns "did the tap land" into an assertion instead of a paragraph in a manual.

Two facts a harness has to be built around, both found the hard way:

- **`adb install -r` and `am force-stop` both clear `enabled_accessibility_services`.** Every
  reinstall and every force-stop must re-grant, or the app correctly decides the service is off and
  sends the user to Settings.
- **`adb shell input tap` does not reach the Overlay while Auto Click's own gesture is in flight**,
  although it does reach the launcher and the notification shade at the same moment. This is a
  property of the injection path, not of the window: `dumpsys` shows the control window as
  `NOT_FOCUSABLE` only — touchable, `alpha=1`, channel `status=NORMAL, responsive=true`, with the
  tapped point inside its frame. A harness must drive Stop through the notification, which is one
  of the reasons `OV-15` puts it there.

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

### What the emulator has actually shown (Pixel 10 Pro XL, API 37)

Run by hand rather than by a harness, so it is a record and not yet a regression test. Where a
claim is about a coordinate it was read from `dumpsys window windows` rather than from a screenshot,
because the bug in `OV-31` is exactly the size of a status bar and the eye does not measure that.

- The **Overlay** draws over another application, and the application underneath keeps working.
- A `tap` **Step** with a 20-second hold makes the launcher open its **long-press menu** — a real,
  sustained touch delivered to somebody else's window.
- The countdown, the run, and `FinishReason` reaching the control (`OV-16`, `OV-17`).
- **Marker**s are not drawn while running (`OV-11`).
- Stop from the run notification works **mid-stroke** (`OV-15`).
- The **Step** panel takes focus and opens a keyboard for `setText`, and drops focus again
  (`OV-20`).
- `SM-14`'s "forgets its profile" clause, end to end: changing the last **Step** to `setText`
  leaves `"screenProfile": null` in `scenario.json`.
- `OV-26`: creating a **Scenario** leaves the Activity and drops the control on the launcher.
- `OV-27`, the one that could not have been reasoned about: with a **Marker** on screen and
  draggable, a tap next to it **opened Chrome from the launcher**. Touch reaches the application
  underneath and the handle at the same time, with no mode in between.
- `OV-14`: the control drags by its handle, snaps to the nearer side, survives a restart, and
  re-hugs its side when a run changes its width.
- `OV-31`, by `dumpsys` rather than by eye: a **Marker** handle's window frame is
  `[606,1430][738,1562]`, whose centre is exactly the **Step**'s point `(672, 1496)`. Before the
  fix it was `[606,1589][738,1721]` — centred on `(672, 1655)`, 159 pixels below the point the
  **Gesture** actually lands on. **This was wrong before this work and had not been noticed**: the
  full-screen **Marker** layer was laid out inside the system bars too.
- `OV-13`: with the panel open, the control's frame ends at `y=1846` and the panel's begins at
  `y=1846`. They no longer overlap, and the control is re-attached last so nothing is drawn over
  Stop.
- `OV-25`, the bug that started this round: the run notification no longer offers Stop when there
  is nothing to stop, and the state refuses the transition regardless.
- **Recording, end to end** (`RD-2` to `RD-5`, `RD-8`). Two taps four seconds apart, in Gmail,
  produced exactly two Steps at exactly the coordinates touched, with
  `"delayMillisecondsAfter": 4045` on the first — the measured pause, not a rounded one. Gmail
  **advanced to its next screen while being recorded**, which is `RD-5` working. A 400ms swipe
  recorded as a `swipe` of `407` milliseconds, which is what it actually took.
- `PK-1` to `PK-3`, end to end: *add a step* took the editor off the screen, a 700-pixel drag
  became a `swipe` between exactly its two ends, and the **Step** carried the default 200ms travel
  rather than the 400ms the drag took — which is `PK-2`'s whole point.
- `OV-32`, by `dumpsys`: the panel's frame is now `[0,1616][1344,2992]`. It was `[0,1582][1344,2920]`
  — seventy-two pixels short of the display, with the application underneath showing through below
  the sheet. Adding the flags alone did **not** fix it; the frame stayed at 2920 until the negative
  offset went in too.
- `OV-33`: the control window measured 840×228 and now measures 792×144, with six buttons instead
  of five. *Done* took the Overlay from fourteen windows to one.
- `OV-34`, both phases. With twelve **Step**s the sheet opened at its peek of 1376 pixels, a drag
  on the grabber took it to 2753 — its full extent — and a further swipe in the body left the
  window at 2753 while the content moved. With five **Step**s the same drag settled at 1791,
  because that is all the content there was: the sheet is bounded, not sized.
- `DS-7`: the grey wedge at the control's bottom corners is gone. Where the old build measured 159
  and 204 against a white application, the same points now read 240 and 241 — the wallpaper — and
  the darkening above and below the window differs by six levels rather than being offset downward.

### What the emulator disproved

`DS-6` is here rather than above because the emulator **refuted** a design decision rather than
confirming one.

- **Cross-window blur is unusable in this application.** `supports_background_blur` is 1 and
  `isCrossWindowBlurEnabled` returns true, so the control's `FLAG_BLUR_BEHIND` was accepted. Every
  other Overlay window then stopped answering touches: `InputDispatcher` logged
  `Untrusted touch due to occlusion by /1000` and named `Dim Layer for - Display 0 …
  mode=BLOCK_UNTRUSTED`. Asking for a blur creates that layer, and Android's untrusted-touch rules
  drop touches to any untrusted window beneath it. Removing the blur restored input immediately,
  which is how it was proved rather than guessed.
- **The blur was not happening anyway.** Before that was found, a row of Gmail's body text sampled
  through the control gave two values, 92 and 43, in the same proportion as the sharp text beside
  it — unblurred text at the surface alpha, not a frost. Whether a device that really does blur
  would also block the touches is untested and now moot.

- `RD-5`'s failure mode, before it was fixed: one tap produced `recorded a touch of 0ms` and
  `recorded a touch of 1ms`, 41ms apart — the layer recording its own re-emission. Two guards
  rather than one, and the same test then gave two touches for two taps.

**Currently unverified — no physical Android device is in use on this project.** Everything below is
untested until one is:

- The **latched-touch freeze** itself, and whether cycling the accessibility service clears it. The
  whole value of the one-tap *free the touch* recovery rests on this, and it is a promise that must
  not be made in the interface until it has been seen to work on a phone.
- Vendor power optimisers — Samsung One UI sleep, MIUI, and their habit of stopping a service that
  looks idle. Reported as a cause of silent death across the category.
- Skin-specific **Overlay** restrictions.
- **Stop on the floating control, pressed mid-stroke, with a real finger** (`OV-13`). The window is
  demonstrably able to take the touch — see the `dumpsys` evidence above — and the notification
  path is proven, but a finger on the control mid-gesture has never been tried. `OV-13` claims Stop
  is reachable at every moment of a run; that claim is currently supported by the window's
  configuration rather than by having seen it work.
- **The run notification opens collapsed**, in the *Silent* section, so Stop and *free the touch*
  need one expand before they can be pressed. `OV-15` wants them reachable in a panic; the
  **Quick Settings tile** added for `GX-12` is the answer to that, and the tile itself has not been
  pressed on hardware either.
- **The whole restricted-settings sequence** (`PM-4`, `PM-7`, `PM-8`). Tier 2 grants the service
  with `appops` and `settings put`, which skips the wall entirely, so the one part of onboarding
  that exists *because* the platform fights the user is the part nothing has exercised.
- **`PM-11`** — Advanced Protection. The API is read and the screen is written, and no device here
  has the mode to turn on.
- Real touch latency and how a game reacts to a synthetic touch arriving beside a real one.
- Whether an application detects the accessibility service and refuses to run.
- Whether one window per **Marker** (`OV-27`) stays smooth at fifteen **Step**s. The emulator was
  fine at one and two; nothing has drawn a full-sized **Scenario** yet.
- **Recording with a real finger.** Everything above went in through `adb shell input`, which
  produces a clean synthetic touch. A finger is messier: it wanders inside the slop, it arrives and
  leaves at speeds `input` does not reproduce, and `RD-3`'s tap-versus-swipe decision is made on
  exactly that. The 24ms window in which `RD-5` drops a touch has also only ever been met by taps
  arriving seconds apart.
- **The sheet under a real finger.** `adb shell input swipe` with a 400ms duration produced too
  few motion events for Compose to recognise a drag at all, and the sheet did not move; the same
  gesture over 900ms worked. A finger produces far more events than either, so this is an artefact
  of the harness rather than a defect — but it means `OV-34`'s drag has only ever been driven by a
  synthetic gesture slow enough to be seen.
- **Whether a re-emitted swipe is good enough to use.** `RD-5` says plainly that it will arrive
  late; nobody has yet recorded a drag in an application that cares.

### Platform behaviour worth knowing about

- **A full-screen `FLAG_NOT_TOUCHABLE` overlay is forced to 80% alpha.** The system logs
  `setting alpha to 0.80 to let touches pass through` and does it whether asked or not. It applies
  to the **Marker** line layer, which is the only window that is both full-screen and untouchable,
  so the lines are drawn at four-fifths opacity and there is nothing to be done about it.
- **`adb shell input swipe` starting at a screen edge is taken as a back gesture** before any
  window sees it, which makes edge-anchored drags awkward to script. Start the swipe a little way
  in.

## Not automated on purpose

Driving the system permission dialogs with UiAutomator. The dialogs change wording and layout
between Android versions, so those tests break when Google edits a label rather than when this code
is wrong — the most brittle coverage available, bought at the highest maintenance price.

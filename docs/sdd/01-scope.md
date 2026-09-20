# 01 — Scope and slices

## The problem

Auto Click can currently emit only **one** kind of operation (a left click) repeated N times at
one point. The goal is to grow it into a **Scenario** runner — an ordered sequence of varied
operations — and to let scenarios be created by **recording** the user's real work.

### Primary use case: games

The project owner uses Auto Click mainly to play games. That cannot be read out of the source but
decides a fair number of things in the specification, so it is recorded here:

- What you need to aim at in a game has **almost no text** — it is an icon, a drawn button, an
  item slot. **Text** recognition (`DM-15`) is therefore secondary; **template matching**
  (`DM-14`) is what carries the feature. That is also why the `I1`…`I8` practice targets in the
  [manual tests](../manual-e2e-tests.md) deliberately contain no text.
- Game interfaces are full of **near-identical** things — five item slots in the same frame, two
  buttons differing only in shade. Template matching has to tell them apart; "close enough" is
  not good enough.
- A game usually has **one** window, and often **renames** it per level. That is why `DM-23`
  treats the window title as a **preference** rather than a hard requirement.
- What you need to aim at almost always stays where it was cropped, so the default search region
  hugs that spot (`RG-23`) instead of scanning the whole screen.

## Slices

Every slice leaves a runnable, installable app. The order is settled; see
[ADR-0001](../adr/0001-screencapturekit-and-min-macos-14.md) for why recognition was pushed last.

### Slice 1 — The Scenario framework  ✅

Replace the runner beneath the Start button without changing what the user can do.

- The **Scenario / Step / Action / Target** model
- A single Scenario runner; **Simple mode** builds a one-step Scenario
- **Target**: at the cursor, absolute point
- **Action**: click(button, count, hold), scroll, move
- Directory-based storage; the editor window
- Release the mouse button on stop (`SF-1`)

Done when: everything possible in version 1.2.0 is still possible, and runs through the new
runner.

### Slice 2 — Window anchoring, drag, typing  ✅

- **Target** relative to the **Anchor window** by nearest corner
- **Action**s drag and type
- Bring the **Locked application** to the front before typing (`SF-4`)

### Slice 3 — Recording  ✅

- Capture system-wide mouse events and infer **Action**s from them
- Automatically raise **Target**s to **Anchor window**-relative when a whole session stays inside
  one application

### Slice 4 — Target recognition  ✅

- Raise the minimum to macOS 14, capture the screen with ScreenCaptureKit
- **Target** by **Template** (pyramid matching) and by text (Vision OCR)
- Search region, threshold, timeout, behaviour when nothing is found

### Slice 5 — Two-scale matching and per-key typing  ✅

Not in the original plan; both came out of running the manual tests on real hardware.

- Match **Template**s at two scales so they survive an external display
  ([ADR-0008](../adr/0008-match-templates-at-two-scales.md))
- Type an all-ASCII string **key by key**, so a game sees one key per character
  ([ADR-0009](../adr/0009-type-ascii-key-by-key.md))

### Slice 6 — Interface languages

Preparation for releasing the source. The interface was written entirely in Vietnamese; the
documentation and the log messages were translated earlier, the interface was not.

- `en` as the development language, plus `vi`, `zh-Hans`, `ja`, `es` ([09](./09-localisation.md))
- Switching language inside the application, without a relaunch
- A boundary drawn between **interface text** and **names written into `scenario.json`**
- Layouts that hold five wordings rather than one (`UI-24`, `UI-25`), under test

Done when: adding a sixth language is adding one directory and no Swift.

## Out of scope

Stated explicitly so it does not get proposed again:

- **Control flow inside a Scenario.** No `if`, no branches, no conditional loops. "Wait until the
  button appears" is the timeout on resolving a **Target**, not a loop.
- **Keyboard capture.** See [ADR-0003](../adr/0003-no-keyboard-capture-when-recording.md).
- **Capping idle time while recording.** See
  [ADR-0004](../adr/0004-recordings-keep-real-timing.md).
- **Running Scenarios on a schedule** or triggering them from another application.
- **Syncing Scenarios between machines.**

# 03 — Execution semantics

There is exactly **one** runner. **Simple mode** builds a one-step **Scenario** and hands it to
that same runner ([ADR-0002](../adr/0002-step-is-action-times-target.md)).

## Lifecycle of a run

- **EX-1** `[Slice 1]` `[done]` The sequence: validate → request permissions if missing → bring
  the **Locked application** to the front (if any) → 3-second countdown → run the loops → finish.
- **EX-2** `[Slice 1]` `[done]` Refuse to run when: the **Scenario** is empty, `DM-18` is
  violated, the **Locked application** is not running, or the Accessibility permission is missing.
  Each case has its own message.
- **EX-3** `[Slice 1]` `[done]` The 3-second countdown can be cancelled; cancelling during the
  countdown emits **no** events at all.
- **EX-4** `[Slice 1]` `[done]` The loop: `for each Scenario repetition { for each Step { for each
  Step repetition } }`.
- **EX-5** `[Slice 1]` `[done]` A **Step**'s delay applies after **every** repetition of that
  **Step**, including the last. This is a deliberate difference from version 1.2.0 (which dropped
  the delay after the final click): it means the gap between two **Scenario** repetitions needs no
  rule of its own.

## Resolving a Target

- **EX-6** `[Slice 1]` `[done]` A **Target** is resolved **immediately before each repetition of
  the Step**, not once for the whole **Step**. `DM-19` depends on this.
- **EX-7** `[Slice 2]` `[done]` Resolving `windowRelative` needs an **Anchor window**; if no
  window can be read, stop the **Scenario** with a message naming the application.
- **EX-8** `[Slice 4]` `[done]` Resolving `template`/`text` retries at a cadence equal to the
  **Step**'s delay, at least 150 ms, until `waitMs` runs out. On timeout, follow `onTimeout`
  (`DM-16`).
- **EX-9** `[Slice 4]` `[done]` `skipStep` skips **all** remaining repetitions of that **Step**,
  not just the current one.

## Locked application

- **EX-10** `[Slice 1]` `[done]` Before every event **with coordinates**, if there is a **Locked
  application**, ask Accessibility which process owns that point; a different PID from the locked
  one stops the **Scenario**. This is pre-existing behaviour, kept as is (`ClickRoutingPolicy`).
- **EX-11** `[Slice 1]` `[done]` If the **Locked application** quits mid-run, stop the
  **Scenario**.
- **EX-12** `[Slice 2]` `[done]` Keyboard events have no coordinates, so `EX-10` cannot apply;
  see `SF-4` instead.

## Stopping

- **EX-13** `[Slice 1]` `[done]` Stopping is triggered from: the button in the popover, the button
  on the floating panel, the `⌥⌘S` shortcut, or an error. Every path goes through the same place.
- **EX-14** `[Slice 1]` `[done]` When stopping for any reason — including task cancellation — the
  runner **must** release every held mouse button before exiting. See `SF-1`.
- **EX-15** `[Slice 1]` `[done]` After stopping, the displayed status states the reason:
  completed, stopped by the user, or an error (with its description).

## Event emission details

- **EX-16** `[Slice 1]` `[done]` A `click` with `count = n` emits `n` consecutive
  `mouseDown`/`mouseUp` pairs, setting the `mouseEventClickState` field to `1, 2, … n` in turn.
  Without that field AppKit treats it as `n` separate clicks, **not** a double click.
- **EX-17** `[Slice 1]` `[done]` The gap between two pairs within one `click` is 30 ms, comfortably
  inside the system double-click interval.
- **EX-18** `[Slice 1]` `[done]` With `holdMs > 0`, `mouseUp` is emitted exactly `holdMs` after
  `mouseDown`; the cursor does not move between the two events.
- **EX-19** `[Slice 1]` `[done]` Every event is posted to `.cghidEventTap` so the destination
  application treats it like real input.
- **EX-20** `[Slice 2]` `[done]` A drag emits `mouseDown` at the start point, 24 evenly
  interpolated `mouseDragged` events 8 ms apart, then `mouseUp` at the end point. Many
  applications **ignore** a drag if the cursor jumps straight from start to end with nothing in
  between.
- **EX-21** `[Slice 2]` `[done]` `typeText` uses `keyboardSetUnicodeString` rather than looking up
  key codes, so it does not depend on the keyboard layout and can type Vietnamese and emoji alike.
  The string is sent in **chunks**, not character by character — see `EX-24`.
- **EX-22** `[Slice 2]` `[done]` `pressKey` emits the physical key code with modifier flags
  attached directly to the event. Modifiers are **not** emitted as separate events, so cancelling
  mid-way leaves no key stuck down — quite unlike the mouse button in `SF-1`.
- **EX-23** `[Slice 2]` `[done]` For a drag, only the **start and end points** are checked under
  `EX-10`. Asking Accessibility at every intermediate step would make the drag stutter and could
  stop it mid-way, leaving a held mouse button for `SF-1` to clean up.
- **EX-24** `[Slice 2]` `[done]` `typeText` splits the string into chunks of **at most 20 UTF-16
  units**, one key down/up pair per chunk, spaced by `SF-8`. It never splits a surrogate pair;
  doing so would shatter an emoji into two pieces of garbage.

  **What was observed, measured through the app itself:** the character-by-character version typed
  `"Xin chào 123 — ăn"` into TextEdit and produced `"Aa chào 123 — ăn"` — reproducibly, including
  when TextEdit was already frontmost. The substituted character is always `a`, exactly the
  character for the `virtualKey: 0` the event carries, meaning the Unicode payload is lost and the
  system falls back to the key code. After switching to chunks: **8 out of 8 correct**, measured
  the same way. That is the entire basis for this change.

  **What is not known, and must not be speculated about further:** the root cause. Ruled out
  experimentally — not the Vietnamese input method (disabling EVKey entirely still failed), not
  the send rate (60 ms still failed), not the destination tap (`hid`/`session`/`annotated` behave
  identically), not `virtualKey` (switching to a key that produces no character typed **nothing at
  all**), not a race with `activate` (reproducing the code path exactly with 0 ms of waiting was
  6/6 correct). **There is also no trustworthy failure rate:** this machine has a Vietnamese input
  method that holds characters in a composition buffer, so reading the document back via
  AppleScript cannot distinguish "not yet committed" from "lost", and the measurements changed
  entirely depending on how the document was cleared between runs. Every quoted rate has been
  withdrawn. See [ADR-0007].

  `B10` of the manual tests is still **broken** after this change: a Scenario with two `typeText`
  steps produces `"â"` instead of `"[B10b]"`. Cause not found, not fixed — **left open
  deliberately**: typing strings is a low priority and basic testing is enough.
- **EX-25** `[Slice 2]` `[done]` A window **minimised into the Dock** must not be used as the
  **Anchor window**. Accessibility still reports its old position and size as though it were still
  on screen; trusting that makes `windowRelative` resolve to a coordinate pointing at empty space,
  or into another application's window. Found while running `B5` of the manual tests: `EX-10` did
  block the click, but the error blamed "the point is outside the locked application", so it
  pointed at the wrong place.

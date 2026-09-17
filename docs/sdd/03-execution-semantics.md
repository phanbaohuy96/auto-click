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
- **EX-21** `[Slice 2]` `[done]` `typeText` takes one of **two routes, chosen by the string's own
  contents** (`EX-26`). A string that is entirely ASCII is typed key by key through real key codes;
  any other string uses `keyboardSetUnicodeString` in **chunks** (`EX-24`), which is the only way to
  send `ằ` or an emoji. Neither route depends on a fixed keyboard layout.
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

  This route is now reached **only by strings containing a character outside ASCII** (`EX-21`,
  `EX-26`). The root cause is still unknown; what changed is how much rides on it.

- **EX-26** `[done]` A `typeText` **Step** whose string is **entirely ASCII** is typed **key by
  key**: one key down/up pair per character, carrying the character's real key code, `25 ms` apart.
  The key code is resolved through the **currently active keyboard layout** at run time, never from
  a fixed table. A character the layout cannot produce with at most Shift and Option sends the whole
  string by `EX-24` instead.

  Two reasons, and the second is the one that matters here. It **avoids the lost payload of `EX-24`
  altogether** rather than touching it less often, because ASCII needs no Unicode payload. And it
  gives the destination **one key per character**, which is what the primary use case needs:
  `ADR-0007` recorded that chunked typing makes an application see "one key carrying 20 characters,
  not 20 keys", and that games react key by key. See
  [ADR-0009](../adr/0009-type-ascii-key-by-key.md).

  `25 ms` is about 40 keys per second — faster than a person, slower than a frame. Games drop input
  arriving inside one frame, and a dropped key is another silent loss of characters.

- **EX-27** `[done]` Before typing key by key, the **input source is switched to ABC**, and it is
  **restored on the stop and cleanup path** — beside `SF-1`'s mouse-button release, not at the end
  of typing.

  Key-by-key characters pass **through** the active input method, which the `EX-24` route bypassed.
  Telex folds `aa` into `â` and `as` into `á`, so `"pass"` would be typed `"pá"`. This is observed,
  not theoretical: it is why `B10` produced `"â"`. Restoring on the cleanup path is what stops
  `⌥⌘S` part-way through a string from leaving the user's input source changed — the same class of
  mistake as leaving a mouse button held down.

  **Measured insufficient (`B15`).** This defends only against input methods registered with Text
  Input Services. EVKey, the one actually in use on the development machine, is **not** a TIS source
  — it is an event tap — so selecting ABC does not disable it and the transformation still happens:
  `"password aa dd"` was emitted correctly key by key and arrived as `"Pasword â đ"`. The events
  EVKey replays carry `virtualKey: 0` with a Unicode payload, the mechanism `EX-24` exists because
  of. What this requirement covers is therefore real but partial, and the gap is **not** covered
  anywhere else.
- **EX-25** `[Slice 2]` `[done]` A window **minimised into the Dock** must not be used as the
  **Anchor window**. Accessibility still reports its old position and size as though it were still
  on screen; trusting that makes `windowRelative` resolve to a coordinate pointing at empty space,
  or into another application's window. Found while running `B5` of the manual tests: `EX-10` did
  block the click, but the error blamed "the point is outside the locked application", so it
  pointed at the wrong place.

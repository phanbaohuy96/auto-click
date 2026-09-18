# 05 — User interface

## Surfaces

- **UI-1** `[Slice 1]` `[done]` The menu-bar popover is the **running surface**: pick a
  **Scenario**, Start/Stop, Record, open the editor window, and **Simple mode**. It contains no
  **Step** editor.
- **UI-2** `[Slice 1]` `[done]` The editor window is the **configuration surface**: resizable, two
  columns — the **Step** list on the left, the selected **Step**'s detail on the right.
- **UI-3** `[Slice 1]` `[done]` The app is an agent (`LSUIElement`), so opening the editor window
  must be accompanied by `NSApp.activate` — otherwise the window appears but takes no keyboard
  input.
- **UI-4** `[Slice 1]` `[done]` The popover closes when the user clicks outside it. Anything that
  **requires** clicking outside (picking a point, cropping a **Template**) has to run from the
  editor window or from a full-screen overlay, never from the popover.

## Simple mode

- **UI-5** `[Slice 1]` `[done]` Keeps the 1.2.0 controls: interval, repeat count, position (at the
  cursor / fixed point), application lock.
- **UI-6** `[Slice 1]` `[done]` Pressing Start in **Simple mode** builds a one-step **Scenario**:
  `click(left, 1, 0)` with the matching **Target**, **Step** repeat count = the entered repeat
  count, delay = the entered interval, **Scenario** repeat count = 1.
- **UI-7** `[Slice 1]` `[done]` A **Scenario** built from **Simple mode** is **not** saved to
  disk. It is a temporary object, created afresh on every Start.

## Step editor

- **UI-8** `[Slice 1]` `[done]` Each list row shows: the ordinal, an **Action** summary, a
  **Target** summary, the repeat count if `> 1`, and the delay if `> 0`.
- **UI-9** `[Slice 1]` `[done]` Reorder by dragging; add, duplicate and delete **Step**s.
- **UI-10** `[Slice 1]` `[done]` The detail panel shows two separate pickers — **Action** and
  **Target** — matching the orthogonal model, plus the parameter fields each choice implies.
- **UI-11** `[Slice 1]` `[done]` Every edit saves immediately; there is no Save button.
- **UI-12** `[Slice 1]` `[done]` Editing is disabled while the **Scenario** is running.

## Running status

- **UI-13** `[Slice 1]` `[done]` A floating panel appears while running, always visible, with a
  Stop button, showing: which **Scenario** repetition out of how many, and which **Step** out of
  how many.
- **UI-14** `[Slice 1]` `[done]` An unlimited **Scenario** shows the number of repetitions so far,
  with no total.
- **UI-15** `[Slice 1]` `[done]` The `⌥⌘S` reminder is always on the floating panel — it is the
  way out when a click sequence has taken over the cursor.
- **UI-16** `[Slice 2]` `[done]` The status line must **distinguish an error from a success**, and
  an error message **must not be truncated**. Previously every non-running state was drawn with
  `checkmark.circle`, so the line *"Error: …"* appeared with the success icon, and was clipped to
  one line so the cause could not be read in full. Found while running `B3` of the manual tests.
- **UI-17** `[Slice 2]` `[done]` Icon buttons sharing a row must be **the same size**. Each SF
  Symbol has its own natural width, so at default sizing `plus`, `doc.on.doc` and `trash` came out
  at three different sizes — measured on the AX tree: 37×20, 40×26, 38×24. They are now all 44×28.
- **UI-18** `[Slice 2]` `[done]` The **editor** window is split into three columns: the
  **Scenario** list on the left, Scenario configuration and the **Step** list in the middle, Step
  detail on the right. The Scenario list used to live in a drop-down menu, where you could not see
  what you had.

  Scenario-level configuration is laid out **vertically**: the middle column is only about 380
  points wide, and packing it horizontally squeezed a label to 0 points and stretched a checkbox
  into a 21×208 stripe.
- **UI-19** `[Slice 2]` `[done]` A **Template** is shown as the image itself, not as a filename —
  the name is `3f2a91c0.png`, which tells you nothing. The real pixel size stays in the tooltip
  because it determines the scan area and the matching speed. A missing file says so plainly
  instead of showing an empty box.
- **UI-20** `[Slice 2]` `[done]` The message line below the configuration is not always a reason
  the Scenario **cannot run**: the recorder reports **success** through it too. `"Đã ghi 3
  bước."` once appeared with an orange `exclamationmark.triangle.fill`, looking exactly like a
  failure — the same bug as `UI-16` on the status line, just somewhere else. Only a message the
  user has to act on carries the warning icon.
- **UI-21** `[done]` The detail panel of a `typeText` **Step** says **which of the two routes**
  (`EX-21`) the string will take, and that the key-by-key route switches the input source to ABC
  (`EX-27`).

  The route is chosen from the string's contents, so two strings in the same **Step** behave
  differently: `"hello"` reaches the game as five keys, `"hellò"` as one key carrying five
  characters. That is the price of not adding a switch to the panel, and it is only acceptable if
  the panel stops it from being something the user has to guess.

## Interface language

- **UI-22** `[Slice 6]` `[done]` The language picker lives in the **popover**, in the settings area
  below the divider, next to the launch-at-login toggle. It is a `.menu` picker, not `.segmented`
  like the two above it: six entries mixing Han characters with Latin script do not fit a popover
  fixed at 340 points.

  Not in the editor window: someone who only ever uses **Simple mode** never opens it, and would
  have no way to find the setting at all. The full reasoning is in
  [`09-localisation.md`](./09-localisation.md) (`LC-5`…`LC-8`).

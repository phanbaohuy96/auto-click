# 02 — Data model

The core shape and the reason for it: [ADR-0002](../adr/0002-step-is-action-times-target.md).

## Scenario

- **DM-1** `[Slice 1]` `[done]` A **Scenario** has: a stable identifier, a name, an ordered list of
  **Step**s, a repeat count, and an optional **Locked application**.
- **DM-2** `[Slice 1]` `[done]` A **Scenario**'s repeat count is `1…1_000_000` or **unlimited**
  (runs until the user stops it).
- **DM-3** `[Slice 1]` `[done]` The **Step** list may be empty. An empty **Scenario** is valid to
  save but not valid to run (`EX-2`).

## Step

- **DM-4** `[Slice 1]` `[done]` A **Step** has: a stable identifier, exactly one **Action**,
  exactly one **Target**, a repeat count `1…1_000_000`, and a delay after finishing of
  `0…3_600_000` ms.
- **DM-5** `[Slice 1]` `[done]` There is no "wait" **Action**. A delay is a property of a
  **Step**. To wait 5 seconds before doing something, put the delay on the **Step** before it.

## Action

- **DM-6** `[Slice 1]` `[done]` `click(button, count, holdMs)` — `button` ∈ {left, right, middle},
  `count` `1…10`, `holdMs` `0…60_000`. `count = 2` is a double click; `holdMs > 0` is a long
  press.
- **DM-7** `[Slice 1]` `[done]` `scroll(dx, dy)` — in lines, each axis `-10_000…10_000`.
- **DM-8** `[Slice 1]` `[done]` `move` — only moves the cursor to the **Target**, pressing
  nothing.
- **DM-9** `[Slice 2]` `[done]` `drag(to: Target)` — press and hold at the **Step**'s **Target**,
  move through intermediate points, release at the destination **Target**.
- **DM-10** `[Slice 2]` `[done]` `typeText(text)` and `pressKey(combination)` are two separate
  **Action**s, not one **Action** in two forms: one enters content, the other issues a command.
- **DM-21** `[Slice 2]` `[done]` A key combination stores the **key name** in readable form
  (`"c"`), not the numeric code (`8`). The numeric code is the physical position on the keyboard —
  accurate, but unreadable when you open `scenario.json` to look at it.
- **DM-22** `[Slice 2]` `[done]` The modifier list is normalised (duplicates removed, sorted) when
  built, so two identical combinations always compare equal and always serialise to the same JSON.

## Target

- **DM-11** `[Slice 1]` `[done]` `cursor` — the cursor position at the exact moment the **Step**
  runs.
- **DM-12** `[Slice 1]` `[done]` `screenPoint(x, y)` — absolute coordinates in `CGEvent` space
  (origin at the **top-left** of the main display, in **points**).
- **DM-13** `[Slice 2]` `[done]` `windowRelative(corner, dx, dy)` — `corner` ∈ {topLeft, topRight,
  bottomLeft, bottomRight} of the **Anchor window**. The corner is chosen **automatically when the
  point is recorded**: the corner nearest the point.
- **DM-14** `[Slice 4]` `[done]` `template(templateName, threshold, searchRegion?, waitMs,
  onTimeout)`.
- **DM-15** `[Slice 4]` `[done]` `text(string, searchRegion?, waitMs, onTimeout)`.
- **DM-16** `[Slice 4]` `[done]` `onTimeout` ∈ {stopScenario, skipStep}.
- **DM-17** `[Slice 4]` `[done]` `searchRegion` is optional and **never** requires a **Locked
  application**. It is stored in the most durable form available at the moment it is drawn: as an
  offset from a corner of the **Anchor window** if the **Scenario** has a **Locked application**
  and the window can be read, otherwise as absolute screen coordinates. See `RG-6`.

- **DM-23** `[done]` The **Locked application** also remembers the **Anchor window title** at
  recording time.

  Remembering only the bundle id cannot point at a window. At run time the **Locked application**
  is resolved in two steps, and both used to be far too broad: take the **first process** matching
  the bundle id, then take **its focused window**. Two browser profiles, or two copies of a game
  open side by side, are two processes sharing a bundle id; and one process opens as many windows
  as it likes. The consequence: a Scenario recorded on a scratch window replays onto the
  logged-in window, at exactly those coordinates.

  With a title, we prefer the process **that has a window carrying that title**, and then within
  that process we prefer that window. The title is a **preference, not a hard requirement** — it
  changes constantly (opening a different file, switching tabs) — so a mismatch falls back to the
  old behaviour rather than refusing to run. Preference rather than refusal because the primary
  use case is games: a game window often renames itself per level, and refusing to run would break
  the feature outright.

  The field is **optional**: older files without it still load, and a **Locked application**
  chosen by hand in the editor has no title to store. `RC-14` warns when a recording spans two
  **applications**; spanning two **windows** of one application cannot be warned about, because a
  recording anchors to exactly one window.

  Found while preparing `D10` of the [manual tests](../manual-e2e-tests.md).

## Invariants

- **DM-18** `[Slice 2]` `[done]` A **Scenario** containing a **Step** with a `windowRelative`
  **Target** **must** have a **Locked application**; without one the **Scenario** is not valid to
  run. This constraint does **not** apply to `searchRegion` and does **not** apply to `template`
  (`DM-17`, `RG-4`).
- **DM-19** `[Slice 1]` `[done]` `cursor` combined with a repeat count `> 1` is valid: every
  repetition re-reads the cursor position, so the click sequence follows the user's hand.
- **DM-20** `[Slice 1]` `[done]` Every numeric field is clamped into its valid range when **read
  from disk**, without raising an error. One broken field must never lose a whole **Scenario**.

# A Scenario has no branches, and a Step may only decide its own fate

`01-scope.md` has forbidden control flow inside a **Scenario** since the first slice, but only as a
bare "no `if`". Surveying the Android market (`android/docs/landscape.md`) made the refusal worth
defending properly, because every competitor took the other road — and because `skipStep` (`DM-16`)
is a conditional, so "no conditionals" was never literally true and the line had to be drawn
somewhere more precise.

## The boundary

**A Step may decide its own fate. A Step may never decide another Step's fate.**

That single rule settles every case that has come up:

| Allowed | Why |
|---|---|
| `skipStep` — this Step does not run | Decides itself. The list is still read top to bottom, every entry either happens or does not. |
| `stopScenario` — everything ends here | Terminal. There is no jump target. |
| `repeatCount` on a Step, `runCount` on a Scenario | Counters, not conditions. |
| A timeout while resolving a **Target** | The Step waiting on its own resolution. |

| Forbidden | Why |
|---|---|
| `if` / `else` with Steps inside | One Step decides whether others run. |
| `goto`, labels, jumps | The list can no longer be read in order. |
| `while` / `repeat until` over a range of Steps | A backwards jump is still a jump. |
| Subroutines, nested **Scenario**s | Same, with a return address. |
| "Skip the next 3 Steps if not found" | The tempting one. Still one Step deciding others' fate. |

The property being protected is not minimalism. It is that **a Scenario can be read top to bottom,
once, and understood** — and that the on-screen **Marker**s of the Android app can show the whole
Scenario as a numbered path, which is impossible the moment a branch exists.

## Guarded Steps are what replaces `if`/`else`

This is the part that makes the refusal survivable, and it needs to be said out loud or the first
person to want a branch will conclude the model cannot do their job.

To do X on screen A and Y on screen B, do **not** ask for a branch. Write two Steps, each guarded by
its own **Template** with `skipStep`. On screen A the first resolves and the second is skipped; on
screen B the reverse. The effect of `if`/`else` without a jump, without a nesting level, and without
a reader ever having to hold two futures in their head.

## Considered options

- **Follow Macrorify.** Three tiers — drag-and-drop actions, a visual editor with `if`, loops and
  variables, and EMScript, a real scripting language. Unquestionably more powerful. Rejected: it is
  a product that already exists and is years ahead, and the thing users complain about in it and in
  Klick'r is the *same thing* — the learning curve. Competing there means competing on the axis
  where the incumbent is strongest and its users are least happy.
- **Allow `if` but not loops.** Rejected: `if` alone already destroys top-to-bottom readability and
  the **Marker** path, which is the whole cost, while delivering little that guarded Steps do not.
- **Keep the refusal, state the boundary.** Chosen.

## Consequences

- The market is split between dumb-but-easy and powerful-but-steep, with nothing in between. This
  decision is a deliberate claim on that middle ground, and it is a **product** position, not a
  scheduling one — "add `if` later" is not a smaller version of this, it is the other option.
- Some things become genuinely inexpressible, and the honest one is "keep going until the target
  disappears". Addressing that must not be done with a loop.
- Any future request for control flow is answered by this document, not re-litigated.

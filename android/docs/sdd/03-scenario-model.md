# 03 — Scenario model (Android)

The shape is macOS's, unchanged: a **Scenario** is an ordered list of **Step**s, and a **Step** is
an **Action** paired with a **Target** ([ADR-0002]). What changes is the alphabet — five
**Action**s instead of six, one **Target** form instead of five — and one thing macOS has no need
of: every coordinate is bound to a **Screen profile**.

## The Scenario

**SM-1** `[A1]` A **Scenario** has an identifier, a name, an ordered list of **Step**s, a run count,
a countdown, and exactly one **Screen profile**.

**SM-2** `[A1]` Run count is either a number of iterations or *until stopped*. A **Step** always
uses a plain number.

**SM-3** `[A1]` The countdown is the delay between the user starting a **Scenario** and its first
**Step**, so that the finger that pressed Start is out of the way. It is per-**Scenario** and
configurable, default three seconds. It is **not** a schedule — see the out-of-scope note in
[01](./01-scope.md).

**SM-4** `[A1]` A **Scenario** read from disk with no name is given `"Untitled scenario"`,
deliberately **untranslated**. It is a repair value, not a name the user chose, and it is written
back on the next save; translating it would let an interface setting rewrite user data, and would
give the same damaged file a different name on every phone. Mirrors macOS `LC-11`.

## The Step

**SM-5** `[A1]` A **Step** has an identifier, an **Action**, a **Target**, a repeat count and a
delay observed after it finishes.

**SM-6** `[A1]` The repeat count repeats the **Action** in place. It does not repeat the delay after
the last repetition.

## The Actions

**SM-7** `[A1]` There are exactly five **Action**s. Adding a sixth is a specification change, not an
implementation detail.

| **Action** | Carries | Reaches its **Target** |
|---|---|---|
| `tap` | a hold duration | yes |
| `swipe` | a destination point and a duration | yes, as the start point |
| `multiTouch` | two or more paths performed together | yes, as the first path's start |
| `globalAction` | which system operation | **no** |
| `setText` | the string to write | **no** |

**SM-8** `[A1]` `globalAction` and `setText` ignore their **Step**'s **Target** entirely. The model
still requires one, so that a **Step** is always an **Action** × **Target** and nothing has to be
made optional; the runner discards it. Stated here because a **Marker** that does nothing would
otherwise look like a bug — a **Step** with one of these **Action**s draws no **Marker** at all.

**SM-9** `[A1]` `setText` writes the whole string into whichever field holds input focus, and
presses nothing. It is not typing, and [ADR-0009] does not apply here.

**SM-10** `[A1]` `globalAction` names one of the fixed system operations — Back, Home, Recents,
Notifications, Quick Settings, Lock screen, Screenshot — by name and never by a numeric constant,
so a `scenario.json` stays readable and survives a platform renumbering. Mirrors macOS `DM-21`.

## The Target

**SM-11** `[A1]` A **Target** in A1 is a fixed point, in **raw device pixels**, inside the
**Scenario**'s **Screen profile**. The cursor and window-relative forms have nothing to attach to on
Android and are absent; the **Template** form arrives with A3.

**SM-12** `[A1]` A coordinate is never stored as a fraction of the screen. [ADR-0013] gives the
reasoning; the consequence is `SM-15`.

## The Screen profile

**SM-13** `[A1]` A **Screen profile** records the width and height of the usable display in pixels,
the density in dpi, and the rotation.

**SM-14** `[A1]` A **Scenario** captures the **Screen profile** in force when its first **Marker**
is placed, and keeps it — it is not re-captured when a later **Step** is edited on a different
screen, because that would swap it for one the coordinates were never measured against and the
mismatch at `SM-15` would never be reported at all.

It **forgets** the profile when its last **Marker** goes, whether by the **Step** being deleted or
by its **Action** changing to one that ignores its **Target**. The profile exists to make
coordinates meaningful; with no coordinates there is nothing left to protect, and a profile kept
past its last **Marker** would block a run that could not press anything wrong.

**SM-15** `[A1]` Before the countdown starts, the current **Screen profile** is compared with the
**Scenario**'s. Any difference **blocks the run**, with a message naming what changed. The block is
not dismissible: acting on coordinates measured against another screen is the one failure that
presses the wrong thing on purpose. [ADR-0013].

## Limits

**SM-16** `[A1]` Every numeric field has a range. A value read from disk that falls outside its
range is **clamped into it**, not rejected — one bad number must not cost the user a whole
**Scenario**. Mirrors macOS `DM-20`.

| Field | Range | Why this bound |
|---|---|---|
| scenario run count | 1…1,000,000 | as macOS |
| step repeat count | 1…1,000,000 | as macOS |
| delay after a step | 0…3,600,000 ms | as macOS |
| countdown | 0…60,000 ms | past a minute it is a schedule, which is out of scope |
| tap hold | 0…60,000 ms | the platform's own maximum gesture duration |
| swipe duration | 1…60,000 ms | same, and zero would be a tap |
| multi-touch paths | 2…10 | the platform's own maximum stroke count |
| set text length | 0…5,000 characters | beyond this no field is a text field |

**SM-17** `[A1]` The two bounds marked *the platform's own* are read from
`GestureDescription.getMaxGestureDuration()` and `GestureDescription.getMaxStrokeCount()` rather
than written as literals, and the constants above are what those return today. A **Step** that
would exceed either is refused at the editor, not at the dispatcher: a gesture rejected mid-run is
a **Step** that silently did nothing.

## What is deliberately absent in A1

- **Guard** — it needs recognition, which is A3. A1 has no conditions of any kind.
- **Template** and text **Target**s — A3.
- Anything from the macOS model with nowhere to attach: cursor **Target**, window-relative
  **Target**, **Locked application**, `pressKey`, `move`.

[ADR-0002]: ../../../docs/adr/0002-step-is-action-times-target.md
[ADR-0009]: ../../../docs/adr/0009-type-ascii-key-by-key.md
[ADR-0013]: ../adr/0013-coordinates-are-raw-pixels-bound-to-a-screen-profile.md

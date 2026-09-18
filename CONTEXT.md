# Auto Click

A macOS menu-bar app that emits synthetic mouse events to automate repetitive work.
This document is the project's **glossary**, not a spec.

## Language

**Scenario**:
An ordered, user-named sequence of operations that runs start to finish as one unit.
_Avoid_: macro, workflow, script, profile

**Simple mode**:
The cut-down surface for quickly configuring one repeated operation, which underneath still builds a one-step **Scenario**.
_Avoid_: old mode, basic mode, legacy mode

**Step**:
One unit inside a **Scenario**, made of exactly one **Action** and exactly one **Target**.
_Avoid_: action (when you mean the pair), command, task

**Action**:
What a **Step** does — click, long press, scroll, move, drag, type — kept separate from where it does it.
_Avoid_: event, operation, step kind

**Target**:
Where an **Action** happens, resolved to concrete coordinates only at the moment that step runs.
_Avoid_: destination, coordinates, point, anchor

**Template**:
A patch of screen the user cropped, used to find the target again at run time when coordinates cannot be trusted.
_Avoid_: sample image, snapshot, pattern

**Search region**:
The part of the screen narrowed down to look for a **Template**; optional, and it never forces a **Scenario** to have a **Locked application**.
_Avoid_: search frame, scope, bounds

**Anchor window**:
The window of the **Locked application** that relative **Target**s are measured from. It is the **recorded window** — recognised by its title — not whichever window happens to be in front at run time; only when that fails does it fall back to the frontmost one.
_Avoid_: main window, focused window

**Recording session**:
The span of time Auto Click listens to the user's real mouse work in order to build a **Scenario**.
_Avoid_: record, capture

**Locked application**:
The only application allowed to receive events when the user turns the restriction on; entirely distinct from **Target**.
_Avoid_: destination app, target app

**Interface language**:
Which translation of Auto Click's **own** menus and labels is on screen. It is a display setting and nothing else: it never decides what text OCR can read, and never decides how characters are typed.
_Avoid_: language (unqualified), locale, region

**Recognition language**:
The language Vision is told to expect when looking for a text **Target** — the language of the **application being automated**, not of Auto Click.
_Avoid_: OCR language setting, text language

**Input source**:
The keyboard layout or input method in effect while a `typeText` **Step** runs. What Telex folds `aa` into `â` is this, not a language.
_Avoid_: keyboard language, typing language

## Relationships

- **Simple mode** produces exactly one one-step **Scenario**; it is not a separate way of running.
- Every automated operation, whichever surface it came from, executes through the same **Scenario** runner.
- A **Scenario** holds one or more ordered **Step**s.
- A **Step** pairs exactly one **Action** with exactly one **Target**; the two axes are independent.
- A delay is a property of a **Step**, not an **Action**. There is no "wait" **Action**.
- A **Locked application** constrains the whole **Scenario**, not individual **Step**s.
- A **Target** comes in four forms: at the cursor, an absolute screen point, an offset from a corner of the **Anchor window**, and the centre of a located **Template**.
- A window-relative **Target** can only be resolved when a **Locked application** is set; without one the **Scenario** is invalid.
- A **Template** **Target** is the opposite: it needs no **Locked application**, and a **Template** can be cropped from anywhere on screen, including from a screenshot open in another application.
- One **Recording session** produces exactly one **Scenario**; it watches the mouse only, never the keyboard.
- A **Template** or text **Target** may fail to resolve; the **Step** then retries until its timeout expires and either stops the **Scenario** or is skipped, as that **Step** itself specifies.
- **Interface language**, **Recognition language** and **Input source** are three independent settings that share a word. None of them is derived from another, and wiring any two together is a bug.

## Example dialogue

> **Dev:** "If we keep the Simple tab, do we have to write a second click loop?"
> **Domain expert:** "No. **Simple mode** is just an input funnel; it builds a one-step **Scenario** and hands it to the same runner."
>
> **Dev:** "So 'click on an image' is a new **Action**?"
> **Domain expert:** "No, 'on an image' is a **Target**. The **Action** is still a click. That is what keeps 'scroll at an image' or 'double-click on an image' from being new concepts at all."
>
> **Dev:** "Then 'wait for the Save button to appear, then click it' needs a conditional loop?"
> **Domain expert:** "No. That is a **Step** clicking a **Template** **Target** with a 10-second timeout. A **Scenario** has no branches and no conditions — only counters and timeouts."

## Flagged ambiguities

- "two modes side by side" originally implied two independent runners — settled: two **interface** surfaces, one runner.
- "target" in the existing code carried two meanings: `targetMode` (where to click) and `targetProcessIdentifier` (which app may receive the click) — split into **Target** and **Locked application**.
- "record" once implied capturing everything the user does — narrowed: a **Recording session** captures the mouse only; typing steps are added by hand.
- "the search region is always anchored to the window" was reversed: window anchoring is now a preference used when available, because requiring it would block cropping a **Template** from a screenshot.
- "wait" was once listed as an **Action** — corrected: it is a property of a **Step**.
- "long press" is settled as holding in place; **drag** is its own **Action**.
- "wait until the button appears" is not control flow — it is the timeout on resolving a **Template** **Target**.
- "fixed point" once meant only absolute coordinates; it is now two distinct **Target** forms — absolute, and relative to the **Anchor window**.
- "language" is the most overloaded word in the project: it means the **Interface language**, the **Recognition language**, or the **Input source**, depending on who is speaking. They look connected and are not — a Vietnamese menu says nothing about whether the game on screen is in Vietnamese, and neither says anything about what EVKey will do to a keystroke. Settled by naming all three; see `LC-13`.
- "name" carries two meanings too, and they are the interface/data boundary: a **Scenario**'s name is data written into `scenario.json`, so it is translated once, when created, and never again. `KeyCatalog`'s `name` is an identifier and is never translated at all — only its `title` is.

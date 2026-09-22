# 06 — The Overlay and Markers (Android)

macOS has a menu bar, windows and a cursor. Android has none of those while another application is
in front, so **every** surface Auto Click offers during authoring or running is drawn on top of
somebody else's screen. That is the **Overlay**, and it is why this document is long.

Compose runs there by hand-wiring three owners onto a `WindowManager` view: [ADR-0015].

## The windows

**OV-1** `[A1]` There is more than one **Overlay** window, because they need different things from
the system:

| Window | Present while | Receives touches |
|---|---|---|
| Floating control | a **Scenario** is open or running | yes, on itself only |
| **Marker** layer | editing | yes, on the **Marker**s only |
| **Step** panel | one **Step** is being configured | yes, on itself only |

**OV-2** `[A1]` Every **Overlay** window is `TYPE_APPLICATION_OVERLAY` and passes through every
touch that is not on one of its own controls. The application underneath must behave exactly as it
does without Auto Click installed; a tool that intercepts stray taps is worse than no tool.

**OV-3** `[A1]` **No Overlay window takes input focus**, with the single narrow exception in
`OV-20`. `FLAG_NOT_FOCUSABLE` is not an optimisation here. `setText` finds the field with
`findFocus(FOCUS_INPUT)` (`GX-17`), so an **Overlay** that takes focus makes every `setText`
**Step** write into Auto Click instead of the application being automated — a failure that looks
like the other application's fault.

**OV-4** `[A1]` A window is removed from `WindowManager` when it stops being needed, not hidden.
An **Overlay** left attached keeps drawing, keeps a `ViewModelStore` alive, and is what turns
[ADR-0015]'s stated risk into a leak.

## Markers

**OV-5** `[A1]` A **Marker** is drawn for each **Step** whose **Action** uses its **Target**
(`SM-8`). A `setText` or `globalAction` **Step** draws none, and its place in the order is shown in
the **Scenario** list instead.

**OV-6** `[A1]` A **Marker** carries the **Step**'s position in the **Scenario**, counting from 1.
Reordering the **Scenario** renumbers every **Marker** immediately. Order is the one thing a
spatial layout cannot show by itself.

**OV-7** `[A1]` A **Marker** is placed by dragging and configured by tapping. Dragging writes raw
pixels into the **Step**'s **Target**, at the **Screen profile** in force (`SM-14`).

**OV-8** `[A1]` A swipe **Step** draws **two** **Marker**s joined by a line, the start carrying the
**Step** number and the end carrying an arrow. Dragging either end edits that end.

**OV-9** `[A1]` A **multiTouch** **Step** draws one numbered **Marker** per path, all carrying the
same **Step** number, so it is visible that they happen together rather than in sequence.

**OV-10** `[A1]` A **Marker** cannot be dragged outside the screen (`SM-17`). It stops at the edge
rather than being refused on save.

**OV-11** `[A1]` **Marker**s are not drawn while a **Scenario** runs. They would be tapped by the
very **Gesture**s they describe.

## The floating control

**OV-12** `[A1]` The floating control is always reachable, in both states:

- *stopped* — Start, add a **Step**, open the **Scenario**, collapse
- *running* — Stop, the **Step** currently running, and nothing else

**OV-13** `[A1]` Stop is the largest target in the running state, and is reachable at every moment
of a run (`GX-8`). Nothing is ever drawn over it.

**OV-14** `[A1]` The control is dragged anywhere on screen and remembers where it was left, per
device, in `DataStore` (`FS-4`). It collapses to a small bubble and expands on tap, because it
spends most of its life in the way of something.

**OV-15** `[A1]` **Free the touch** (`GX-11`) is on the control and in the run notification. It is
in both places because a latched touch is exactly the situation in which the control cannot be
tapped.

## Running, seen from the Overlay

**OV-16** `[A1]` The countdown (`GX-3`) is shown in the control, counting down, with a cancel that
is the same Stop.

**OV-17** `[A1]` When a run ends for any reason other than finishing, the reason is shown where the
user is already looking — in the control — and not only in a notification they have to pull down.
A **Screen profile** mismatch (`SM-15`) is shown before the countdown and names what changed.

## Lifecycle

**OV-18** `[A1]` Every **Overlay** window is created through one host in `:core` that supplies the
`LifecycleOwner`, `SavedStateRegistryOwner` and `ViewModelStoreOwner` Compose requires, and that
**clears the `ViewModelStore` when the window is removed**. It is written once and never
re-implemented per feature — [ADR-0015] calls this the place where this goes wrong if it goes
wrong.

**OV-19** `[A1]` Opening and closing an **Overlay** window many times leaks nothing. This is
checkable without a device and is therefore under test, not left to inspection.

## The Step panel

**OV-20** `[A1]` The **Step** panel is the one window permitted to take input focus, and only
while a field inside it holds the caret. A `setText` **Step**'s string has to be typed somewhere,
and a window that cannot take focus cannot open a keyboard. The two alternatives are worse for the
same reason: an Activity takes focus just the same, and editing the string only in the main
application means leaving the screen being automated.

What makes the exception safe is **when the panel exists**, not the flag itself. The panel is drawn
only while nothing is running — it is derived from the state, not closed by a call somebody
remembers to make — so the window `findFocus(FOCUS_INPUT)` would find during a `setText` **Step**
is never this one. Both halves are under test: the flag in `:core`, the state rule in the
coordinator.

**OV-21** `[A1]` The panel edits everything about a **Step** **except where it touches**. Points
are dragged on the **Marker** layer, where the user can see what they are aiming at (`OV-7`); a
pair of coordinate boxes would be a worse way to set the same value and would disagree with the
layer about it.

The **Marker**s show the **draft**, not the **Step** last written to disk, so choosing `swipe`
draws the destination immediately rather than after a save. While the panel is open a drag
therefore edits the draft too — one rule, *everything in the panel is a draft until Save* — because
the alternative loses work: a drag written straight to disk would be silently undone by the next
Save.

**OV-22** `[A1]` Save is offered only when the **Step** has no violations (`SM-17`), and every
violation is listed at once rather than one at a time. Cancel discards. Delete and the two move
buttons apply immediately: they change the **Scenario**'s shape rather than this **Step**'s fields,
which is the same immediacy dragging a **Marker** already has.

**OV-23** `[A1]` A **Step** added from the floating control lands in the middle of the screen and
opens the panel on itself. The middle because it is the one place certain to be visible and not
under the control — it is a starting position to be dragged from, not a guess at what was meant.

**OV-24** `[A1]` Every **Step** is reachable from the panel, including the ones that draw no
**Marker**. `globalAction` and `setText` have nothing to tap (`SM-8`), so without a way to walk the
**Scenario** they would be writable once and never openable again. Walking away is refused while
there are unsaved edits, rather than silently discarding or silently saving them: both are guesses,
and Save and Cancel are already on screen to be asked.

[ADR-0015]: ../adr/0015-compose-in-the-overlay.md

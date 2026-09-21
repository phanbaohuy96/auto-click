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

**OV-3** `[A1]` **No Overlay window ever takes input focus.** `FLAG_NOT_FOCUSABLE` is not an
optimisation here. `setText` finds the field with `findFocus(FOCUS_INPUT)` (`GX-17`), so an
**Overlay** that takes focus makes every `setText` **Step** write into Auto Click instead of the
application being automated — a failure that looks like the other application's fault.

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

[ADR-0015]: ../adr/0015-compose-in-the-overlay.md

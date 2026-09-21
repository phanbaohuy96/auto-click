# 05 — Gesture execution (Android)

What happens between the user pressing Start and the last **Step** finishing, and — more
importantly — what happens when they press Stop.

`dispatchGesture()` is the only way in, and it has a property `CGEvent` does not: a stroke is
**stateful**. A press that is never released leaves a finger on the screen that is not there. The
device then stops responding to the real finger and the user reboots it. That is the single most
common complaint about every app in this category (see [`../landscape.md`](../landscape.md)), and
most of this document exists because of it.

## Running

**GX-1** `[A1]` The runner walks the **Step**s in order and does nothing else. No branching, no
jumps, no loops over a range of **Step**s — [ADR-0011].

**GX-2** `[A1]` Before anything else, the current **Screen profile** is compared with the
**Scenario**'s, and a difference blocks the run (`SM-15`). The check happens **before** the
countdown, so the user is not made to wait to be told no.

**GX-3** `[A1]` Then the countdown runs (`SM-3`), visibly, and is cancellable.

**GX-4** `[A1]` A **Step** with a repeat count performs its **Action** that many times, observing
the minimum gap between gestures, and observes its delay once after the last repetition.

**GX-5** `[A1]` Two consecutive gestures are separated by at least 10 ms even when both delays are
zero. Mirrors macOS `SF-8`: without a yield the run is a tight loop that starves the main thread it
needs in order to be stopped.

**GX-6** `[A1]` `dispatchGesture()` is asynchronous. The runner waits for the completion callback
before starting the next **Step**, with a timeout of the gesture's own duration plus one second.
A gesture that never reports back is treated as cancelled, which takes the run through `GX-9`.

**GX-7** `[A1]` A run happens inside a foreground service with an ongoing notification, so the
system does not kill it and the user can always see that something is driving their phone.

## Stopping

**GX-8** `[A1]` Stop is honoured **between strokes and during one**. A stroke in flight is
completed rather than abandoned — `dispatchGesture` has no cancel that guarantees a release — and
no further **Step** begins. The interface says "stopping" for however long that takes, which is at
most one gesture's duration.

**GX-9** `[A1]` Every exit path terminates every stroke: finishing normally, Stop, a cancelled
gesture, the service being turned off, the foreground application changing if the user asked for
that, an exception anywhere in the runner. This is the Android form of macOS `SF-1`, and it is the
requirement with the highest cost of being wrong.

**GX-10** `[A1]` A stroke is never dispatched with `willContinue = true` unless the continuation is
already queued. A continuing stroke that is never continued is exactly the stuck finger this
document opens with.

**GX-11** `[A1]` **Free the touch.** A control the user can always reach dispatches a single
one-millisecond tap through the service and then, if the screen is still unresponsive, offers to
turn the accessibility service off and on again. The first is cheap and usually enough; the second
is the only thing that is known to clear a latched touch, and is **unverified on hardware** — see
[`../testing.md`](../testing.md).

**GX-12** `[A1]` The control is reachable without the **Overlay**, because a latched touch may be
the reason the **Overlay** cannot be tapped. It is also a notification action.

## The Actions

**GX-13** `[A1]` `tap` is one stroke: down at the **Target**, up at the same point, lasting the
hold duration. A hold of zero is dispatched as a 1 ms stroke, because zero-duration strokes are
rejected by the platform.

**GX-14** `[A1]` `swipe` is one stroke from the **Target** to the destination over the given
duration. The path is a straight line; nothing is interpolated into it, because unlike macOS
(`EX-20`) Android delivers the whole stroke to the system rather than a sequence of events.

**GX-15** `[A1]` `multiTouch` is one gesture carrying every path as a separate stroke, dispatched
together. Every stroke starts at the same moment.

**GX-16** `[A1]` `globalAction` calls `performGlobalAction()` and ignores the **Step**'s
**Target** (`SM-8`).

**GX-17** `[A1]` `setText` finds the input focus with `findFocus(FOCUS_INPUT)` and performs
`ACTION_SET_TEXT`. If there is no focused editable node the **Step** **fails visibly** rather than
doing nothing: the usual cause is that the tap meant to put focus there did not land, and silence
would hide it. What happens next follows the **Scenario**'s setting, the same one `DM-16` governs
on macOS.

**GX-18** `[A1]` No **Action** waits for the screen to change. Nothing here observes the result of
what it did; recognition is A3.

[ADR-0011]: ../../../docs/adr/0011-a-scenario-has-no-branches.md

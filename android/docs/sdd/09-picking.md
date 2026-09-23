# Picking — aiming one Step at the screen underneath

`PK` requirements. The other half of building a **Scenario**: [08](./08-recording.md) captures a
sequence the user performs, this captures a single place the user points at.

## Why it exists

Adding a **Step** used to drop one at the centre of the display and open the panel on it. The
centre is never where the **Step** belongs, so the first drag was unavoidable — and it happened
with the panel open over the very thing being aimed at. The **Marker** started in the one place
guaranteed to be wrong.

**PK-1** `[A2]` *Add a step* hides the editor and arms the screen for one gesture.

The panel closes, the **Marker**s go, and a display-sized layer takes the next touch. The floating
control stays, wearing a hint and a *Cancel* — it is a separate window, so a tap on *Cancel* is
unambiguous. A *Cancel* drawn inside the picking layer would be a target that same layer is trying
to record, and the two readings of one tap cannot both be right.

The layer's border is the **accent**, where recording's is red (`RD-6`). Red says *this screen is
being recorded and what you do is being kept*; the accent says *this screen is waiting for you to
point at something*. In one of them the application underneath is reacting to the finger and in the
other it deliberately is not, so the user has to be able to tell which is in force.

**PK-2** `[A2]` One gesture becomes one **Step**: a tap makes a `tap`, a drag makes a `swipe`
between its two ends. **The timing is discarded.**

The shape is read exactly as `RD-3` reads it, using the platform's own `scaledTouchSlop`, so a
finger that wandered a little means the same thing on both routes. The duration is not, and that
is the difference between the two. A recording captures a performance, so how long a finger stayed
down is part of what the user did. Aiming is not a performance; it is somebody choosing a spot
while still deciding. Keeping that duration would turn three seconds of hesitation into a
three-second hold and build a **Step** out of a pause. The **Step** takes the same defaults a
draft made by hand starts with, and the panel that opens next is where a hold or a travel time is
chosen on purpose.

**PK-3** `[A2]` The picked touch is **not** handed to the application underneath.

The opposite of `RD-5`, and deliberately. Recording re-performs what the user did because the
application has to advance through the sequence. Picking must leave the screen exactly where it
was: a screen that navigated away under the finger would take the thing being aimed at with it.

It also means picking cannot loop the way `RD-5` could. Nothing is re-emitted, so there is nothing
for the layer to catch a second time, and neither of that bug's two guards is needed here.

## What was considered and not done

- **Picking with pass-through**, so the user could navigate while aiming. It would let a single
  session place **Step**s across several screens, but every pick would carry `RD-5`'s re-emission
  delay and the target could move under the finger. Recording already covers the multi-screen case
  and covers it better.
- **Two taps for a swipe** rather than a drag. Fewer ways to fail, but three actions instead of
  one, and the drag is what the **Step** is going to do anyway.
- **Picking several Steps without leaving.** Each pick opens the panel, which is usually what is
  wanted; the user who wants a run of them is recording.

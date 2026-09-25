# 08 — Recording (Android)

Placing ten to fifteen **Marker**s by hand, **every time a Scenario is edited**, is the difference
between a tool that works and one that gets used. That is why recording is ahead of recognition
here, the reverse of the macOS order ([01](./01-scope.md)).

Android gives no way to watch touches go by. An application cannot observe another one's input, and
an accessibility service is told *what happened* rather than *where a finger was*. The only way to
learn a coordinate is to **take the touch**, which means the application underneath does not get
it — so everything below follows from one sentence: recording has to swallow a touch and then hand
it back.

## The session

**RD-1** `[A2]` Recording is a mode with a window of its own: a display-sized layer that takes
every touch. While it exists the **Marker**s are gone, the panel is closed, and the floating
control is the only other thing on screen.

Markers are removed rather than dimmed. Each one is a window (`OV-27`), and a window that is merely
faint still takes the touch that was meant for the application underneath.

**RD-2** `[A2]` One finger at a time. A touch is a **down**, any number of **moves**, and an
**up**; a second finger is ignored.

This records taps and swipes. A `multiTouch` **Step** is something the user builds in the panel,
not something they perform — two fingers on a screen that is swallowing touches, being re-emitted
one at a time, would produce a **Step** that does not resemble what was done.

## What a session becomes

**RD-3** `[A2]` A finger that stayed put is a `tap` and keeps **how long it was held**. One that
travelled further than the platform's touch slop is a `swipe` and keeps **how long it took**.

Touch slop is Android's own number, read from `ViewConfiguration`. Using a different one would
disagree with every other application on the phone about what counts as a tap.

**RD-4** `[A2]` The pause **before** each touch becomes the previous **Step**'s delay. The pause
before the first is discarded.

Waiting is something the user did *between* two actions, so it belongs to the gap rather than to
either end of it. The wait before the first touch is somebody finding their aim, which is not part
of what they are automating.

This is [ADR-0004] in Android's vocabulary: a recording keeps real timing rather than normalising
it. A pause longer than a **Scenario** may hold is clamped rather than refused (`SM-16`) — one
out-of-range number must not cost the user the session.

**RD-8** `[A2]` A session is **added** to the **Scenario**, never replaces it.

Recording more onto something half-built is the ordinary case: record, try it, record the next
part. A session that silently threw the earlier work away would make the button too dangerous to
press.

## Pass-through

**RD-5** `[A2]` Every recorded touch is **re-emitted** as a **Gesture** at the same place, over the
same time, so the application underneath reacts and the user can carry on through it.

Without this a session could only ever mark points on one screen, which is most of the value gone:
a sequence that spans several screens is exactly the thing worth recording.

The hard part is that a dispatched **Gesture** goes to the topmost window that accepts touches, and
while recording that window is the recording layer — so it records its own re-emission, and one tap
becomes two **Step**s. It did: on the first run, one tap produced `recorded a touch of 0ms` and
`recorded a touch of 1ms`, 41 milliseconds apart.

Two guards, because one was not enough:

- the layer's touchable flag goes away for the length of the re-emission, which is what lets the
  touch reach the application at all;
- and events are refused outright while a re-emission is in flight, because `updateViewLayout` is
  not applied the instant it is called and that gap is exactly long enough for a synthetic tap to
  slip through it.

**The cost is stated rather than hidden.** A real touch arriving inside that window reaches the
application and is **not recorded**. For a tap it is a few tens of milliseconds.

Two more honest limits, both the platform's rather than ours:

- `dispatchGesture` costs tens of milliseconds, so **taps record faithfully and swipes do not**: a
  continuous drag has to be re-emitted after the finger has already finished, and arrives late.
  Swipes are better adjusted as **Marker**s afterwards.
- While recording, the application underneath is driven by **synthetic** touches. One that treats
  those differently behaves differently while being recorded.

**RD-6** `[A2]` The screen carries a border for as long as the session lasts, and the control says
how many touches have been caught.

Not decoration. `RD-5` means the application underneath is being driven synthetically, and the user
is entitled to know which mode they are in without having to remember. The count is the only other
feedback a session gives — everything else on screen is the other application, behaving normally.

**RD-7** `[A2]` A touch the system takes away is discarded, not recorded and not re-emitted. Half a
touch is not a **Step**, and re-emitting one the user did not finish would do something they never
did.

## Silent

**RD-9** `[A2]` A session is **pass-through** or **silent**, chosen when it starts. Silent records
the touch and hands nothing back: the application underneath is left exactly as it was.

Silent is `RD-5` minus its last step — the same window, the same **Step**s, no re-emission — and it
exists for the case pass-through is bad at: marking six places on **one** screen without setting any
of them off. It is also the only mode in which the application underneath is not being driven
synthetically, so it is the one to reach for in an application that rejects synthetic input; the
price is that it cannot follow a sequence across screens, which is why pass-through is the default
and the mode the floating control offers.

Three consequences that are interface decisions rather than implementation details:

- **The border says which mode is in force.** Red in pass-through, the accent colour in silent. Red
  means *what you do is being done*; the accent means *what you do is only being noted*. `RD-6`
  makes the border a promise, and silent never earns the red one — the same accent, and the same
  reasoning, as `PK-1`'s pick layer.
- **The choice lives in the panel, not on the floating control.** The control is a row of verbs, and
  its record button stays the ordinary one. Choosing between two modes is a decision, and a decision
  belongs where there is room to explain it.
- **Neither label names a mode.** Both say what happens to the application underneath. "Silent"
  means nothing to somebody who has not read this page; *the app will not react* is the whole
  difference.

## Deferred from A2

Stated so the absence is not read as an oversight.

- **Recording a `multiTouch` Step** — see `RD-2`.
- **Editing the recording as it happens.** The session produces **Step**s and the panel edits them
  afterwards, which is one surface rather than two.

[ADR-0004]: ../../../docs/adr/0004-recordings-keep-real-timing.md

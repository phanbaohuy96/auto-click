# A recording session never captures the keyboard

A **Recording session** listens to the mouse only. Typing steps have to be added by hand after
recording.

*Emitting* keyboard events needs only the Accessibility permission we already have, but
*capturing* the keyboard forces a request for **Input Monitoring** — a third permission — and in
substance turns the app into a system-wide keylogger: mistype a password into another window
while recording and that string sits in `scenario.json` in plain text. The mouse path carries no
comparable risk (click coordinates reveal little), so the two paths were decided separately
rather than together.

The option of "record but mask password fields" (relying on AX reporting a secure text field)
was rejected: not every password field declares itself correctly, so it would create a feeling
of safety it could not deliver.

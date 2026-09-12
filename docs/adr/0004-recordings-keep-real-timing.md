# Recordings keep real timing, with no cap

A **Recording session** infers high-level **Action**s from raw events (folding a `scrollWheel`
burst into one scroll step, recognising double clicks, long presses and drags), but it does
**not** touch the intervals between operations — wait 8 seconds and it records 8 seconds.

Capping idle time is the obvious convenience and was rejected deliberately: the recorder cannot
tell "waiting for a page to load" from "gone to make coffee", so it guesses wrong exactly when it
matters most and turns into a "clicked before the UI was ready" bug — the hardest kind of bug to
track down in automation. If you want it faster, use a global speed factor on playback or edit
individual delays by hand; both are the user's decision, not the recorder's guess.

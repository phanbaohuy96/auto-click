# Type strings in chunks, not key by key

The obvious way to automate typing a string is to imitate real typing: one key down/up pair per
character, carrying that character's Unicode string. That is what `KeyboardEventEmitter` did at
first. Manual test `B8` is what revealed it **does not work**.

Typing `"Xin chào 123 — ăn"` into TextEdit produced `"Aa chào 123 — ăn"`. Reproducible, including
when TextEdit was already frontmost so there was no race with bringing the app forward. The
substituted character is always `a` — exactly the character for the `virtualKey: 0` the event
carries, meaning the Unicode payload is lost and the system falls back to the key code. No error
is reported anywhere. A tool that types the wrong characters silently is worse than one that
cannot type at all.

Decided: split the string into chunks of at most 20 UTF-16 units, one key pair per chunk, never
splitting a surrogate pair. That cuts the event count roughly twentyfold, and with it the number
of times we touch whatever is losing the payload. Measured through the app itself, the same way
before and after: before the fix it failed every time, after it **8 out of 8 correct**.

## Root cause: still unknown

This section records what has been **ruled out experimentally**, so nobody repeats it:

- **The Vietnamese input method** (this machine runs EVKey, which sits between the keyboard event
  stream and replays keys under its own pid) — disabled entirely and typing character by
  character **still failed 0/5**.
- **Send rate** — 30 ms wrong, 60 ms still wrong. Not a speed problem.
- **Destination tap** — `cghidEventTap`, `cgSessionEventTap`, `cgAnnotatedSessionEventTap` behave
  identically.
- **A non-zero `virtualKey`** (F13, fn) so that losing the payload would insert *nothing* rather
  than the wrong character — **0/12, nothing typed at all**. Zero is mandatory, not a choice.
- **The whole string in one key pair** — nothing typed.
- **Racing `activate`** — built a tool that reproduces the `bringLockedApplicationToFront` path
  exactly and types the instant `frontmost` matches, with no pause at all: **6/6 correct**.

## No trustworthy failure rate

The first version of this ADR quoted numbers like "about 1 in 5 correct", "≈94%", "about 6% left".
**All of them have been withdrawn.** The measurement was to type into TextEdit and read the
document back via AppleScript, but this machine has a Vietnamese input method that holds
characters in a **composition buffer**: text typed correctly but not yet committed reads back as
**empty** via AppleScript, indistinguishable from lost characters. Proof: typing `"abc"` reads
back `""`, and pressing the right arrow to commit makes it read `"abc"`. The results also changed
entirely with how the document was cleared between runs — resetting it via AppleScript gave
completely different numbers from clearing with `⌘A` + delete.

Put another way: the measuring rig is not good enough to state a rate. Only two things stand,
because they were measured **the same way** before and after: the old version failed
reproducibly, the new one is 8/8 correct.

## Consequences

- The destination application sees **one** key carrying 20 characters, not 20 keys. Anything that
  reacts key by key — games, filter-as-you-type fields — will behave differently from a real
  typist.
- `type` becomes `async`: it has to pause between chunks. `ScenarioRunner.applyKeyboard` follows,
  and `⌥⌘S` can now interrupt part-way through a string.
- **`B10` is still broken.** A scenario with two `typeText` steps (`"["` then `"B10b]"`) produces
  `"â"`. Same failure shape: the payload is lost, it falls back to `a`, and the Telex input method
  folds `aa` into `â`. This change does not touch it. Still open.
- The **clipboard paste** path (save the clipboard, set the string, send `⌘V`, restore) is the
  only approach that avoids the broken mechanism entirely. Weighed and not chosen: it takes over
  the user's clipboard in the middle of their other work, and anything that blocks paste still
  fails.
- **Stopping here by the project owner's decision:** typing strings is a low-priority feature and
  basic testing is enough. The root cause and `B10` are left open deliberately, not by oversight.
  If typing strings becomes a priority later, the clipboard route is the first thing to revisit.

## Superseded in part by ADR-0009

The premise of that last bullet was wrong. The project owner **does** use `typeText` inside games,
in ASCII. [ADR-0009](./0009-type-ascii-key-by-key.md) therefore sends an all-ASCII string key by key
through real key codes, which needs no Unicode payload and so sidesteps this failure completely,
and it reopens `B10` rather than leaving it closed.

What is decided here still stands for every **other** string: there are no key codes for `ằ` or an
emoji, so chunking remains the only way to send them, and the root cause below is still unknown.
The third route was not the clipboard after all.

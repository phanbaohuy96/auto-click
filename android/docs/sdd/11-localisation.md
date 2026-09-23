# 11 — Interface languages (Android)

Slice A4. macOS states the same feature in
[`09-localisation.md`](../../../docs/sdd/09-localisation.md) and solves it with
[ADR-0010](../../../docs/adr/0010-strings-files-and-a-live-bundle-swap.md): a live bundle swap, so
the language changes with no restart.

The same problem arrives here wearing different clothes, and [01](./01-scope.md) said so before the
work started: **the Overlay is not an Activity**, so it never receives the configuration change
that a language change is on Android. Everything below follows from that sentence, as `RD-*`
follows from "recording has to take the touch".

Requirements are numbered `IL-*`. macOS's own localisation requirements are `LC-*`, and the two
prefixes are deliberately different — `SM-4` cites macOS `LC-11`, which is a different rule about
the same repair value.

## The five languages

**IL-1** `[A4]` The interface is available in **English**, **Tiếng Việt**, **中文（简体）**,
**日本語** and **Español**, as on macOS. A language chosen here is remembered and is **not** the
same value as "follow the phone" — the choice is stored as the presence of a setting, and
following the phone as its absence.

Null is not English. A phone set to Japanese shows Japanese without anybody choosing it, and a user
who never opens the picker keeps following their phone for ever — including after they change it.

**IL-2** `[A4]` Each language is offered under **its own name**, because somebody who has set their
phone to a language they cannot read is exactly the person who will come looking for this list, and
"Vietnamese" is no help to them.

The picker lives in the Activity rather than in the Overlay. The Overlay is what the user opens
when they are somewhere else entirely, and a settings menu is not what they went there for.

**IL-3** `[A4]` Only English and Vietnamese have been checked by a person. The other three are
machine translations, as on macOS, and anything missing falls back to English — a translation does
not have to be complete to be worth having.

## How the language reaches the screen

**IL-4** `[A4]` The chosen language is **one process-wide value**, and both surfaces read it from
there.

A singleton, deliberately, and the same shape ADR-0010 settled on. A language is not a property of
a screen or of a window; it belongs to the application. The alternative here is threading it
through **two** window systems, because most of this app's interface is in the Overlay.

**IL-5** `[A4]` The swap happens **inside the one theme both surfaces already pass through**, by
providing a Context whose resources speak the chosen language. Nothing is recreated and nothing
restarts: the words change under the user's finger, on both surfaces at once.

This is the requirement the whole slice exists for. An Overlay window is attached to the window
manager rather than to an Activity, so it is never recreated for a configuration change — left to
the platform it would keep the language it was attached with until the phone was rebooted.

**IL-6** `[A4]` The Context handed down is a **wrapper**, not the one `createConfigurationContext`
returns.

`createConfigurationContext` hands back a Context whose base is the *application*, so anything that
walks the base chain looking for an Activity stops finding one. `OV-26` walks exactly that chain —
it is how opening a Scenario sends the Activity to the back — and the bug this would cause reads
as "opening a Scenario leaves the app in front, but only in Spanish". There is a test.

**IL-7** `[A4]` `LocaleManager.setApplicationLocales` is **not** used.

It arrives at API 33 and [ADR-0012](../adr/0012-min-sdk-30.md) settled on 30, so it would need the
mechanism above as a fallback anyway — two code paths for one feature. It also **restarts the
process** to apply, which would take the Overlay off the screen of whatever the user was in the
middle of automating, and lose a run in progress.

The app still declares its `localeConfig`, so Android 13's own per-app language list offers Auto
Click. A language chosen there is the phone's answer, and "follow the system" follows it.

## What is not translated

**IL-8** `[A4]` **The application's name.** It is the same word in every language.

**IL-9** `[A4]` **`"Untitled scenario"`**, which is `SM-4`'s repair value and not a name the user
chose. Translating it would let an interface setting rewrite user data and would give the same
damaged file a different name on every phone.

**IL-10** `[A4]` **The accessibility service's description in Android's own settings.** The system
renders it from the app's resources at the *system* locale, before this app has run, and there is
no supported way to influence that. It follows the phone, which is where the user is standing when
they read it.

## What the run notification does

**IL-11** `[A4]` The run notification is built with the chosen language, read fresh each time it is
posted.

It is not Compose, so it does not get `IL-5` for free — and it is the one part of this interface
that is read while another application is in front, which makes it the part where being in the
wrong language is most confusing.

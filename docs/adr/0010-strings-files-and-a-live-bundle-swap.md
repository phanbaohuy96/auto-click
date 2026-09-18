# `.strings` files, and a live bundle swap

Auto Click is being prepared for release as open source, and its interface is written entirely in
Vietnamese — 239 string literals across 21 files. `CFBundleDevelopmentRegion` said `vi`. The
documentation and the log messages were translated to English earlier; the interface was not.

The decision is **five languages** — `en` `vi` `zh-Hans` `ja` `es`, with `en` as the development
language — and a mechanism to hold them. Everything below about the mechanism was **measured on
this toolchain** (Swift 6.3.2, macOS 26), because three of the obvious answers turn out not to work
here and none of them fail loudly.

## Which five

"The five most popular languages" is not a fact, it is a choice: the ranking by number of speakers
(`en zh hi es ar`), by App Store revenue (`en zh-Hans ja ko de`) and by developers on GitHub
(`en zh-Hans es pt-BR ja`) agree only on `en` and `zh-Hans`. Since the audience is people who find
the repository and run a menu-bar utility on macOS, the last of those three is the relevant one.

Two candidates were rejected outright:

- **`ar`**, because it brings RTL. The editor is a three-column layout (`UI-18`), the popover has a
  hard `frame(width: 340)`, and the whole **corner offset** Target is built on *"the corner of the
  window nearest the point"*. Under RTL the interface's leading edge flips but **screen coordinates
  do not**. That is not a layout adjustment, it is a risk of silently inverting the meaning of a
  Target, and it would deserve an ADR and manual test cases of its own.
- **`hi`**, because the intersection of {reads Hindi} × {uses macOS} × {wants a click automator} is
  close to empty. It ranks in a table, not in this application's users.

`es` was taken in the knowledge that it is the one choice that **stretches** the layout — Spanish
runs roughly 25–30% longer than English, inside a popover whose width is fixed, and `UI-18` records
a previous occasion when this squeezed a label to zero points. `F2` in the manual tests exists for
that and nothing else. `zh-Hans` and `ja` only shrink it.

## String Catalogs are not available here

`.xcstrings` is Apple's current format and would have been the default choice. **SwiftPM does not
compile it.** Measured: a `.xcstrings` placed in a target's resources is copied into the bundle
verbatim and a lookup against it misses, returning the fallback. Compiling it is a job of Xcode's
build system, and this project has no `.xcodeproj` — it is `swift build` plus a 30-line
`scripts/build-app.sh`.

Adopting `.xcstrings` therefore means adopting an Xcode project, which is a change to how the whole
product is built in exchange for a file format. Rejected.

`.strings` and `.stringsdict` **do** work under SwiftPM — both measured, including plural
selection (`1 step` / `3 steps` from the same entry).

## `Bundle.module` would have crashed on everyone else's machine

This is the finding that most changed the shape of the answer, and it is invisible to the person
who introduces it.

SwiftPM generates the `Bundle.module` accessor with two candidate paths: the resource bundle
alongside `Bundle.main.bundleURL`, and — hardcoded — **an absolute path into the `.build/`
directory of the machine that compiled the binary**. For a macOS `.app`, `Bundle.main.bundleURL` is
the `.app` **root**, not `Contents/Resources`, so the first candidate never matches a bundle placed
where macOS expects one. Measured:

```
--- .build intact ---
module resolved to: …/loctest/.build/arm64-apple-macosx/debug/LocTest_LocTest.bundle
--- .build renamed (another machine) ---
Fatal error: could not load resource bundle
```

It works on the machine that built it, through the fallback, and hard-crashes at the first string
lookup anywhere else. For a project whose whole purpose here is to be cloned, that is the worst
available failure mode.

Decided: **no resources in `Package.swift`, and `Bundle.module` never appears in the source.** The
`.lproj` directories sit in `Resources/` beside `Info.plist` — which `build-app.sh` already reads
from — and are copied into `Contents/Resources/`, where `Bundle.main` finds them the ordinary way.
Measured working: `main localizations: ["en", "vi"]`.

Not using SwiftPM resources also means `Bundle.module` **does not exist** in this module, so the
landmine cannot be reintroduced later by someone reaching for the obvious API.

## Changing language without a relaunch

Writing `AppleLanguages` into the application's own defaults domain is how System Settings →
Language & Region → Applications does it, and it works — but only for the **next** process.
Measured: writing it mid-process leaves `Bundle.main.preferredLocalizations` at `["en"]` and every
string unchanged. `Bundle.main` resolves its language once, at launch, and caches it.

Two blind alleys worth recording, because both look like the answer:

- `String(localized: "greeting", locale: Locale("vi"))` returns **`Hello`**. The `locale:` parameter
  governs *formatting* — plural rules, number shapes — and does **not** select a `.lproj`. The same
  goes for `.environment(\.locale)` in SwiftUI; it is not a language switch.
- Setting `AppleLanguages` and offering to relaunch. Honest, and about fifteen lines. Rejected
  because Auto Click is an `LSUIElement` agent: it has no Dock icon and no window of its own, so an
  application that vanishes and comes back leaves the user with nothing to watch and no evidence it
  returned.

The one mechanism that switches inside a live process is to stop asking `Bundle.main` and hold a
`Bundle` pointing at a specific `<code>.lproj`. Measured: a process running in English returns
`Xin chao` from `Bundle(vi.lproj)` immediately. Swapping that reference is the switch, and a
`@Published` on it is enough for SwiftUI to redraw.

### What that costs, and it is not nothing

**Apple's fallback chain belongs to `Bundle.main`.** A sub-bundle asked for a key it does not have
returns **the key**: `ja.lproj` missing `farewell` yields `"farewell"`, and `value: ""` yields
`"farewell"` as well. Left alone, the first gap in a machine-translated language puts
`editor.step.delay` on screen in the middle of the interface.

Rebuilt with a sentinel: ask with a `value:` no translation can equal, and identity on the way back
means "missing" — then ask `en.lproj`. Six lines, measured returning `Goodbye`. It is written down
here because nobody would guess it was needed; the failure appears only in the language the author
cannot read.

**A mutable global.** `LocalizedError.errorDescription` is a protocol property that takes no
arguments, so `SettingsValidator` has no way to be handed a bundle. A `Localization.current` static
is unavoidable, in a codebase that otherwise injects its seams carefully
(`ScenarioStore(defaults:fileManager:)`). It is settable, so tests still pin it, but it is a step
down and it is the strongest argument that was available for the relaunch option.

**Four `@Published` message properties freeze.** `AutoClicker.message`, `ScenarioRecorder.message`,
`ScenarioRunner.message` and `LaunchAtLoginManager.errorMessage` hold strings already materialised
at the moment of an event, so a language change leaves them in the old language until the next
action. They become enums rendered at display time — which is the shape `SettingsValidationError`
already had, and which incidentally frees six test files from asserting on Vietnamese prose.

## Keys in Swift, translations in `.strings`

A plain-Swift table — one `struct` per language — was considered seriously, because it makes a
missing translation a **compile error**. It was rejected on the one property that matters most for
an open-source repository: a contributor who wants to add Korean would have to edit Swift, and no
translation tool can read it.

The split adopted keeps both halves: **keys** are a `StringKey: String, CaseIterable` enum, so a
mistyped key does not compile and the tests can enumerate every key the code uses; **translations**
stay in `.strings`, so adding a language is still adding a directory.

The completeness test is deliberately **asymmetric** (`LC-15`): `en` and `vi` missing a key fails
the build, `zh-Hans`/`ja`/`es` only report coverage. A symmetric test would turn the build red every
time a label is added until it had been machine-translated into three languages nobody here can
check — and it would contradict the fallback that was just built to make partial translations safe.

## The word *language* now means three things

After this change the codebase contains three unrelated things called *language*, and they must
never be wired to one another (`LC-13`):

| | What it selects |
|---|---|
| **Interface language** | which `.lproj` is being read |
| **Recognition language** | `VNRecognizeTextRequest.recognitionLanguages` — the language of **the application being automated** |
| **Input source** | the keyboard/input method while typing (`EX-27`, [ADR-0009](./0009-type-ascii-key-by-key.md)) |

`TextFinder` is deliberately left alone. It derives its list from `Locale.preferredLanguages`, and
that list is measurably unsound — this machine reports `en-VN`, which is **not** among the 30 tags
Vision supports, and Vision accepts the assignment without complaint. It was checked whether this
breaks anything: rendering `"Lưu cài đặt"` and reading it back gives the correct string under
`en-VN`, `en-US`, `vi-VT` and the default alike. The tag does not matter **because**
`usesLanguageCorrection` is `false`, which makes recognition largely script-driven. So there is no
bug to fix today, only a comment to leave: this is safe only while that flag stays off.

Connecting the new picker to it would be the obvious-looking mistake, which is why it is written
down in three places rather than one.

## Consequences

- Adding a language is adding one directory, forever. If a future change breaks that, it has broken
  the thing this decision was made to buy.
- The interface on the author's own machine becomes **English**: `AppleLanguages` here is `en-VN`,
  so "follow the system" resolves to `en`. That is intended, and the picker is the way back.
- Five languages ship, but only two are reviewed. `zh-Hans`, `ja` and `es` are machine-translated
  and say so in the README and at the head of each file. An empty directory attracts no
  contributors; a rough translation attracts someone irritated enough to correct it, and `LC-7`
  makes correcting twenty keys out of two hundred a safe thing to do.

# Context Map

Auto Click is one product on two platforms. The concepts are shared; almost nothing else is.

## Contexts

- [Auto Click](./CONTEXT.md) — the shared language: **Scenario**, **Step**, **Action**,
  **Target**, **Template**, **Search region**. True on every platform.
- [Auto Click for Android](./android/CONTEXT.md) — **Overlay**, **Marker**, **Gesture**,
  **Foreground application**.
- Auto Click for macOS — **Anchor window**, **Locked application**, **Recording session**,
  **Input source**, **Simple mode**. These still live in the root glossary and are carved out into
  `macos/CONTEXT.md` when the source tree moves under `macos/`.

## Relationships

- **Shared → both**: the **Scenario / Step / Action × Target** model holds unchanged on both
  platforms. A concept that is true on only one of them does not belong in the root glossary.
- **No shared data.** The two platforms share the glossary and the ADRs, **not** `scenario.json`.
  A **Scenario** written by one is never opened by the other; see the ADR on splitting the schema.
- **macOS ⟂ Android** on how an operation is aimed: macOS addresses a **Locked application**
  directly and can anchor to its window; Android hands a **Gesture** to whatever is in front and
  can only observe the **Foreground application**.

## ADR numbering

One sequence across the whole product; the **folder** says which context a decision belongs to.
`docs/adr/` holds shared and macOS-era decisions, `android/docs/adr/` the Android ones. So
ADR-0011 (no branches, product-wide) is followed by ADR-0012 (`minSdk 30`, Android) without either
number being reused.

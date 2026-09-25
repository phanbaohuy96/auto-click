<!--
  Two rules this repository actually runs on:

  1. The specification comes before the code. If behaviour changed, a numbered requirement changed
     first — and if the code cites an identifier, that identifier exists.
  2. A claim is measured or it is not made. CI proves tier 1 on every push. Nothing proves tier 2
     except you, on a device, which is why it is asked for below rather than assumed.
-->

## What changed, and why

<!-- A paragraph, not a list of files. What was wrong or missing, and what the reader gets now. -->

## Checked

- [ ] `cd android && make check` — assemble, JVM tests, detekt, Spotless, coverage. Exactly what CI runs.
- [ ] `cd macos && swift build && swift test --no-parallel` — for a change under `macos/`.
- [ ] Every claim added to a document was checked against the tree, not remembered.
- [ ] A behaviour change moved its requirement number first (`android/docs/sdd/`, `docs/sdd/`).

## Tier 2, on a real emulator

**`cd android && make tier2`.** It is not in CI — six minutes of emulator boot per pull request is
the reason, and `android-tier2.yml` is one uncommented block away if that ever stops being the right
trade. So this section is the only thing standing between a broken `SF-1` and `main`.

Required for anything touching the accessibility service, `ScenarioRunner`, gesture dispatch, the
**Overlay**'s windows, or a **Screen profile**. Paste what the run printed — the harness prints its
own measurements for exactly this purpose:

```
<!-- e.g.
8 tests, 0 failed
15 zero-delay taps took 214ms end to end; gaps between contacts: [15, 14, 13, ...]
aimed at (540, 1200); arrived at (540, 1200) from device -1
Stop asked for after 500ms of a 2500ms stroke: the contact ended 2500ms after it began, and Step 2 never started
-->
```

- [ ] Ran, green, output above.
- [ ] Not applicable — this change cannot affect a dispatched gesture. Say why: <!-- … -->

## What this does not claim

<!--
  The honest gap, every time. No physical Android device is in use on this project
  (android/docs/testing.md), so anything that needs one is unverified — a latched touch, vendor power
  optimisers, real touch latency. Name whatever else you did not check, rather than letting a reader
  assume you did.
-->

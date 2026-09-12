# Use ScreenCaptureKit and raise the minimum to macOS 14

The "on an image" Target needs to capture the screen. `CGDisplayCreateImage` still works on
macOS 26.5 when the binary targets macOS 13 (verified by running it), but the SDK marks it
`SCREEN_CAPTURE_OBSOLETE(10.6, 14.4, 15.0)` — building against a macOS 15 or later target is a
**compile error**, not a warning. We chose `SCScreenshotManager` (macOS 14+) and raised
`platforms` in Package.swift to `.macOS(.v14)`, accepting the loss of macOS 13, so that the
capture path does not have to be rewritten at the next bump.

## Consequences

- The capture path is **async**; the Scenario runner has to `await` every time it resolves an
  image Target.
- It needs the **Screen Recording** permission, separate from the Accessibility permission we
  already have. The app now has two permissions to ask for, and the user can grant one and
  forget the other.

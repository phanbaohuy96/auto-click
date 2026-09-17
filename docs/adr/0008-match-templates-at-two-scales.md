# Match Templates at two scales rather than recording the scale of each one

A **Template** is stored as a PNG of raw captured **pixels**. A display's scale factor decides how
many pixels one point is worth, so the same button is 272×86 pixels when cropped on a 2x built-in
display and 136×43 pixels on a 1x external one. `TemplateMatcher` scans the **Template** at its
native pixel size and nothing else, so a **Template** cropped on one display simply never matches on
a display of the other scale.

It fails silently. Recognition reports "not found", the **Step** retries until its timeout expires
and then stops or is skipped (`EX-8`, `EX-9`), which looks exactly like a target that is not on
screen. The user concludes that recognition is unreliable rather than that the scale is wrong.

This was never seen because the machine the manual tests ran on had one display: `C2` passed on a
single 2x screen where `frame.minX`, `frame.minY` and the scale are all the values that hide a
mistake. `C3` and `C4` — the two cases written to catch exactly this — are recorded as *"Could not
run"*.

## Decided: two scales at match time, native first

`locateTemplate` makes a second attempt only when the first finds nothing above the threshold on
**any** display:

| Display | Second attempt |
|---|---|
| 2x | Match against the **haystack downsampled by 2**, then multiply the point found by 2 |
| 1x | Match against the **Template downsampled by 2** |

The scale of the display being searched is known (`CapturedImage.scale`); the only unknown is the
scale the **Template** was cropped at, and the plausible set is `{1, 2}`. That is what makes two
attempts enough rather than a sweep of ratios.

Three things follow from the ordering:

- **The successful path costs nothing extra.** Cropping and running on the same display — what
  happens every time on a single-display machine — never reaches the second attempt. `C13` stays at
  its measured 560–710 ms.
- **The extra cost lands where it is already being paid.** Only a search that is failing does the
  second attempt, and a failing search is retrying every 150 ms until its timeout anyway.
- **No upscaling is needed in either direction.** `GrayImage.downsampled(by:)` already exists and
  covers both rows of the table. Upscaling a 1x **Template** to 2x would invent detail that was
  never captured and would score worse than downsampling the thing that really does have the detail.

Each attempt is a separate coarse scan, so each stays inside the `RG-18` ceiling of about 40 million
comparisons. `RG-18` is a per-scan budget, not a wall-clock requirement, and is not weakened by this.

## Rejected: record the crop scale in the Template's file name

The alternative was to keep the scale at crop time — it is known, `captureTemplate` currently throws
it away — by naming the file `ab12cd34@2x.png`, and to resample by the exact ratio at match time.
One attempt instead of two, and exact rather than guessed.

Not chosen, because the guessing it avoids is not actually expensive here. The set of candidate
scales has two members, the second attempt only runs on a path that is already failing, and the
first attempt — the one that runs every time — is identical under both designs. What the file-name
scheme buys is therefore a saving on the slow path only, in exchange for:

- **A second encoding of the same fact.** The scale would live in a file name, parsed back out on
  every load, and drift the moment a file is copied or renamed by hand. `templates/` is a directory
  the user can open.
- **Nothing to say about the templates that already exist.** Every **Template** cropped before this
  change has no suffix and would have to be assumed 2x — a guess, in the design whose point was to
  stop guessing, and wrong for anyone who cropped on a 1x display.
- **A migration for no gain on the fast path.**

Record it in the file name if the candidate set ever stops being `{1, 2}` — a 3x display, or a
**Template** deliberately cropped at a ratio of its own. Until then two attempts are cheaper to hold
in the head than a naming convention.

## Also decided: stop guessing the scale of a display

`ScreenCapture.scale(of:)` looked the `SCDisplay` up in `NSScreen.screens` and fell back to `?? 2`
when it found nothing. On a 1x display that guess halves every coordinate and the click lands
somewhere between the display's origin and the target — silently wrong, which is worse than not
clicking at all.

The chain is now `NSScreen` → `CGDisplayCopyDisplayMode` (`pixelWidth / width`, the real scale,
straight from CoreGraphics and independent of `NSScreen`) → **skip the display**. Nothing is
guessed. Not finding a target is a state the user can see and act on; clicking the wrong place is
not.

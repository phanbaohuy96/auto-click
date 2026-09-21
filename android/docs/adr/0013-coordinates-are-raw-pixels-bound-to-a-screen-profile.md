# Coordinates are raw pixels bound to a Screen profile, and a mismatch refuses to run

A **Marker** is dragged to a pixel on a live screen, and that pixel is what `scenario.json` stores —
**not** a fraction of the screen. Alongside it the **Scenario** stores the **Screen profile** the
coordinates were authored under. When the profile at run time does not match, the **Scenario**
**refuses to run** and offers to have its **Marker**s placed again, rather than running approximately.

## Why not normalise

Normalising to `0…1` is the obvious move and it is the wrong one. It survives a change of
resolution, which is the least common of the four ways a screen changes, and it fails silently at
the other three:

| What changed | Normalised coordinates |
|---|---|
| Display resolution (Samsung HD/FHD/QHD) | Correct |
| Aspect ratio (a different phone) | Wrong, silently — the layout is not a stretched copy |
| Orientation | Wrong, silently — an app **re-lays out** when rotated; it does not rotate its pixels, so a Menu button does not travel from one corner to the other, it moves somewhere unrelated |
| Navigation bar present/absent, cutout | Wrong by a band at the edge, silently |

Silently is the operative word. A **Scenario** that taps approximately the right place is worse than
one that will not start, because it taps things nobody chose. That is the **Certainty** pressure in
`01-scope.md`, and it is the same ruling `ST-12` already made for a different reason: *a
`schemaVersion` newer than the app understands makes that Scenario load read-only and refuse to run,
rather than being read wrongly.*

Auto-rotating the coordinates was also considered and is the same mistake wearing a smarter hat.

## Consequences

- A **Scenario** belongs to the screen it was made on. Carrying one to another phone means placing
  its **Marker**s again — stated up front rather than discovered by a misfire.
- The refusal must name **what** differs (resolution, orientation, navigation bar), or it is just a
  wall. Offering "place the Markers again for this screen" is part of the requirement, not polish.
- A mismatch is **blocking**, with no "run anyway". A warning that can be dismissed is dismissed by
  the third time, and then the protection is gone exactly when it was needed.
- Holding several **Marker** sets per **Scenario**, one per orientation, remains possible later and
  stacks on top of this without breaking anything. Going the other way — from normalised back to
  raw — would find every existing **Scenario** already wrong.

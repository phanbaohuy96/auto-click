# 07 — The design system (Android)

Auto Click has two surfaces and they have different problems. The Activity is an ordinary app
screen and can look like one. The **Overlay** is drawn on top of something it does not own — a
game, a dark chat, a white form — and everything below follows from that.

The audit this was written against is the one in `redesign-existing-projects`, which is aimed at
the web. Where its advice assumes a browser it has been translated rather than followed: the
"replace Lucide, it is the AI default" rule, for instance, inverts on Android, where the Material
symbols *are* the platform's own and a third-party set would be the thing that looked imported.

## Type

**DS-1** `[A1]` Two families, **bundled** with the app rather than fetched.

Bundled because Auto Click has no `INTERNET` permission and no intention of asking for one, and
because a font provider is one more thing that can be unavailable at the moment the floating
control has to be legible over somebody else's game.

- **Space Grotesk** names things: headings, titles, and every label on a control. It has a
  squared-off, instrument-panel character, which is what this app is.
- **IBM Plex Sans** says things: body text, and the smallest labels. It was drawn for interfaces
  and holds up at 12sp over an arbitrary background, which is the hardest thing this interface
  does.
- A **Marker**'s number is the one exception: it is set in the body face, because it is read at a
  glance over somebody else's artwork and Space Grotesk's figures are drawn to be distinctive —
  the opposite of what is wanted there.

Both are variable fonts, so three weights cost three entries and not three files. They are
**preloaded at process start**, off the composing thread: the first composition that needs a font
reads it from disk on the thread it is composing on, and that thread — for the floating control —
is the one between the user leaving the app and seeing anything at all.

## Colour

**DS-2** `[A1]` One accent, and the **Overlay** is dark at every hour of the day.

Not a preference, and not "dark mode". The Overlay cannot borrow contrast from a background it
does not own: a light control over a dark game is a white slab, and a light control over a white
form disappears. One high-contrast dark scheme is the only thing that works over both. The
Activity follows the system, in the same palette.

This is also why there is **no dynamic colour**. Material You takes its colour from the wallpaper,
which is the one thing here guaranteed to be somebody else's.

The accent is amber, and it has two jobs. It is not the blue-violet that every generated interface
reaches for, and it is the one hue that stays legible against both a bright and a dark screen.
Anything asking for a second accent is asking for emphasis it has not earned — which is why a
**Marker**'s role is told by whether its disc is filled or hollow rather than by a second and third
hue.

No surface is `#000000`. A true black reads as a hole cut in the screen rather than as a surface.

## Surfaces

**DS-3** `[A1]` The corner radius tightens as things get smaller. A chip inside a panel inside a
rounded window, all with the same corner, reads as a mistake rather than as a system.

**DS-4** `[A1]` Every **Overlay** window has both a **hairline** and a **shadow**, and both are
load-bearing.

The hairline is what gives the control an edge over a dark wallpaper, where the surface is the same
value as the background and the window simply vanishes — it was built without one, tested, and
disappeared. The shadow is what gives it one over a light screen, where the hairline is doing much
less work. Neither alone covers both, and the hairline's value is chosen to be visible against
either end rather than to look right against one.

**DS-5** `[A1]` The app's mark is the **Marker**: a ring with a dot in it, and a fainter,
open-ended ring outside it. A tap, and a repeated one — which is the whole product in two shapes.

It is drawn as a vector rather than generated as an image, because that is what an adaptive icon
wants: it has to survive being masked to a circle, a squircle or a rounded square, and the themed
variant (API 33+) has to hold up in a single colour with no colour to help it. The launch screen
uses the same mark on the same ink, so the first thing the user sees is the thing the app actually
looks like.

## What was considered and not done

- **Material You / dynamic colour** — see `DS-2`.
- **A second accent for success.** The green in the palette exists for the word "Ready" in
  onboarding and nothing else; promoting it would make two accents, and `DS-2` is the reason not
  to.
- **Motion.** Nothing here animates beyond what Material 3 does by itself. The Overlay is drawn
  over content the user is watching, and a control that moves on its own would be a distraction
  from the thing being automated rather than a delight.

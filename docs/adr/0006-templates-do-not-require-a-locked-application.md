# Templates and Search regions do not require a Locked application

The original decision was that a **Search region** is always stored as an offset from the
**Anchor window**, which in turn made a **Locked application** mandatory for every **Step** using
a **Template** **Target**. That has been reversed: cropping a **Template** and drawing a **Search
region** are both independent of the **Locked application**.

The reason is a way of working that the old constraint made impossible: the target you need to
aim at is usually **not on screen yet** while you are writing the **Scenario** — the dialog has
not opened, the button only appears after the page loads. What the user does then is open an old
screenshot in Preview and crop the **Template** out of that. The template then comes from
Preview, while the application to be automated is a completely different one; requiring the two
to match blocks the most natural thing to do.

Window anchoring is still more robust, so it is kept as a **preference used when available**:
with a **Locked application** and a window we can read, the region is stored relative; otherwise
it is stored absolute and the interface says plainly that the search region will drift if the
window moves.

## Consequences

- A **Search region** has two storage forms, and the interface has to say which one each **Step**
  is using — otherwise "not found" becomes an unguessable failure.
- The `DM-18` constraint (a **Locked application** is required) now applies only to the
  `windowRelative` **Target**.

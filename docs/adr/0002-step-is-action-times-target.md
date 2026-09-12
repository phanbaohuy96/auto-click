# Step = Action × Target, and only one runner

The obvious design is a flat `enum Step` (`click`, `doubleClick`, `longPress`, `scroll`,
`imageClick`…). We do not do that: a **Step** is an orthogonal **Action** × **Target** pair. The
reason is that "on an image" belongs to the **Target** axis, not the **Action** axis — mixing the
two into one enum means every new Target form duplicates the entire Action list
(`imageDoubleClick`, `imageScroll`, `imageDrag`…). With 4 Action groups and 4 Target forms, the
orthogonal model gives 16 combinations out of 8 concepts.

Together with this: **Simple mode** is not a second runner. It is an interface surface that
builds a one-step **Scenario** and hands it to the same runner — so that the parts most likely to
be wrong (emitting CGEvents, checking the **Locked application**, converting coordinates) exist
in exactly one copy.

## Consequences

- A few combinations are meaningless (a wait uses no **Target**). Accepted, and we do not build
  extra types to forbid them.
- The editor has to show two pickers per step instead of one flat list.

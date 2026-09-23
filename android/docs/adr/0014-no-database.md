# No database — ADR-0005 migrates, and Room goes unused

A **Scenario** is a directory under `filesDir/scenarios/<uuid>/` holding `scenario.json` and
`templates/`, exactly the shape [ADR-0005](../../../docs/adr/0005-one-directory-per-scenario.md)
settled on for macOS. DataStore holds what `UserDefaults` holds there — the selected **Scenario**
id and the preferences — and nothing else. **Room is not used**, although the
`android-base-structure` template arrives with it wired up, schemas directory and all.

Recorded because the absence is the surprising part. An Android app with no database, built on a
template that ships one, looks like an omission unless it is written down.

## Why

A **Template** is a PNG and has to be a file whichever option is chosen. Put **Scenario**s in SQLite
and they are in a *different* store from their own images — two stores to keep in step, and a delete
that has to clean both. That is the coupling ADR-0005 paid duplicated kilobytes to escape, and Room
does not remove it; it only makes it easier to forget about. Keeping everything in one directory
keeps delete = delete a directory and duplicate = copy a directory.

Performance was considered and is not an argument in any direction. The hot loop is frames arriving
and being searched — at about 2.5 a second rather than the 30–60 this originally assumed, see
[ADR-0016](./0016-screenshots-come-from-the-accessibility-service.md); **Template**s are decoded
once at the start of a run and live in memory afterwards, so storage contributes nothing to it. The one measurable
difference favours files: opening the **Overlay** does not have to initialise a database, validate a
schema and check migrations first, and that delay is one the user feels under their finger.

## Consequences

- Room, its Hilt module, its DAOs and `data/schemas/` are removed from the Android app rather than
  left as decoration. If nothing else needs a database, the app has none.
- Writing `scenario.json` is atomic — temporary file, then replace — as `ST-11` already requires.
- Exporting a **Scenario** stays "zip a directory", so sharing costs nothing to add later, even
  though it is out of scope now: [ADR-0013] means a downloaded **Scenario** refuses to run on
  another phone's screen, and the useful part of sharing is only its shape.

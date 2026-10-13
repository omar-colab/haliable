# Store Atlas — what's in migration 0007, and why

Applied to the live project (`abumevloleevhoqxfnoe`) on 2026-10-13.

The Atlas seeds the **UConn Storrs campus**, not Connecticut at large. A student opens
the app where they actually are and sees where they can eat today. The five invented demo
stores from migration 0002 are deleted.

## The rule every row had to pass

No row is in 0007 without **both** of:

1. **A real coordinate from OpenStreetMap.** Data © OpenStreetMap contributors, under the
   [ODbL](https://www.openstreetmap.org/copyright); credited in-app on the
   Acknowledgements screen, as ODbL requires.
2. **A halal claim published by UConn Dining Services itself**, quoted in the migration
   above each row.

Nothing was invented, and nothing was inferred from a name.

## The five

| Place | Type | Scope | UConn's own words |
|---|---|---|---|
| Gelfenbien Commons (Towers) Dining Hall | restaurant | `halal_options` | "Halal (Muslim) menu offerings will be available Monday through Friday" |
| South Dining Hall (Rome Commons) | restaurant | `halal_options` | "Halal, gluten-friendly, vegetarian, and vegan options at every meal" |
| The Beanery Cafe | cafe | `halal_options` | "Vegan, kosher, and halal menu items are offered daily (while supplies last)" |
| Bookworms Cafe | cafe | `halal_options` | same cafes policy |
| nanoByte Cafe | cafe | `halal_options` | same cafes policy |

Sources: [dining.uconn.edu/locations](https://dining.uconn.edu/locations/) ·
[uc-cafes](https://dining.uconn.edu/uc-cafes/) · [ramadan](https://dining.uconn.edu/ramadan)

The Ramadan page confirms the two stations directly: *"meals will be at the Halal station
at Gelfenbien and South."*

## Why every row is `halal_options` and none is `fully_halal`

These are halal **stations** and halal **menu items** inside facilities that also serve
non-halal food. UConn never claims any of these kitchens is exclusively halal, so neither
do we — that's the "report, don't rule" rule. Students refine each pin in-app by
confirming or disputing it (`vote_store()`, migration 0005).

## Known gaps

- **UConn lists five cafes; only three are in OpenStreetMap.** CrossRoads Cafe and Market
  Cafe have no OSM object, so they're omitted rather than given an approximate pin.
  If you want them, get me a street address and I'll geocode them properly.
- **South Dining Hall isn't in OSM under that name.** It's Lewis B. Rome Commons
  (626 Gilbert Road Ext), which *is* mapped — `way/233918996` — so the coordinate is real,
  not estimated.
- The map fallback (used when location is denied or unset, e.g. in a simulator demo) is
  the campus centre, 41.8077 / −72.2540.

## The statewide list this replaced

An earlier pass collected 18 real halal businesses across Connecticut — Manchester,
Middletown, New Haven, Bridgeport, Danbury, Norwalk. That was the wrong shape for the
demo and was dropped in favour of the campus set. It's preserved in git history
(commit `6079c6e`) if off-campus coverage is ever wanted; the nearest to Storrs was
Halal Meat & Seafoods in Manchester, ~16 miles out. **Nothing within 15 miles of Storrs
exists in OpenStreetMap** — confirmed with exact-match, regex and radius queries. That's a
genuine gap in OSM's coverage, not a bad query.

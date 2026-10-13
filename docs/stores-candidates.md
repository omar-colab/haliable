# Store Atlas — candidate stores for migration 0007

Generated 2026-10-13 from OpenStreetMap via the Overpass API.
Source data © OpenStreetMap contributors, available under the [Open Database License](https://www.openstreetmap.org/copyright) (ODbL).

## How to review

Strike or delete any row you don't want, then tell me and I'll turn the survivors into
`supabase/migrations/0007_real_stores.up.sql`. **Nothing here was invented** — every row
traces to the OSM object in the last column. Where I inferred something, the evidence is
in the *Scope evidence* column so you can disagree with it.

Scope mapping is deliberately conservative, per "report, don't rule":

| OSM tag | → `halal_scope` |
|---|---|
| `diet:halal=only` | `fully_halal` |
| `diet:halal=yes` | `halal_options` |
| no tag, "Halal" in the name | `unverified` — the name is a claim, not a source |

Users can confirm/dispute each pin in-app (the `vote_store` RPC from migration 0005),
so `unverified` is a starting point, not a dead end.

## Candidates

| # | Rec | Name | mi from Storrs | Category | Scope | Scope evidence | Address | OSM |
|---|---|---|---|---|---|---|---|---|
| 1 | **include** | Halal Meat & Seafoods | 16 | `supermarket` | `unverified` | no `diet:halal` tag; only the name implies it | Tolland Turnpike, Manchester 06042 | [node/5337895492](https://www.openstreetmap.org/node/5337895492) |
| 2 | _your call_ | Whole Foods Market | 16 | `supermarket` | `halal_options` | `diet:halal=yes` — halal available, not exclusive | Holly Drive, South Windsor 06074 | [node/11088351797](https://www.openstreetmap.org/node/11088351797) |
| 3 | _your call_ | ShopRite | 26 | `supermarket` | `halal_options` | `diet:halal=yes` — halal available, not exclusive | 45 Shunpike Road, Cromwell 06416 | [node/6503446086](https://www.openstreetmap.org/node/6503446086) |
| 4 | **include** | Middletown Halal Grill and Pizza | 27 | `restaurant` | `unverified` | no `diet:halal` tag; only the name implies it | 570 Main Street, Middletown 06457 | [node/2954479168](https://www.openstreetmap.org/node/2954479168) |
| 5 | _your call_ | Shawarma Zone | 27 | `restaurant` | `halal_options` | `diet:halal=yes` — halal available, not exclusive | 560 Main Street, Middletown 06457 | [node/13356076209](https://www.openstreetmap.org/node/13356076209) |
| 6 | **include** | Shah's Halal Food | 27 | `restaurant` | `fully_halal` | `diet:halal=only` — exclusively halal | 344 Main Street, Middletown 06457 | [way/661906623](https://www.openstreetmap.org/way/661906623) |
| 7 | _your call_ | Parsley | 27 | `restaurant` | `halal_options` | `diet:halal=yes` — halal available, not exclusive | 324 Main Street, Middletown 06457 | [node/6196878552](https://www.openstreetmap.org/node/6196878552) |
| 8 | **include** | Halal Munchies | 28 | `restaurant` | `halal_options` | `diet:halal=yes` — halal available, not exclusive | 690 Washington Street, Middletown 06457 | [node/9446184897](https://www.openstreetmap.org/node/9446184897) |
| 9 | _your call_ | Asia Supermarket | 31 | `supermarket` | `halal_options` | `diet:halal=yes` — halal available, not exclusive | North Broad Street, Meriden 06450 | [node/9724238859](https://www.openstreetmap.org/node/9724238859) |
| 10 | _your call_ | Sliders | 37 | `restaurant` | `halal_options` | `diet:halal=yes` — halal available, not exclusive | Mulberry Street, Southington 06479 | [node/14152751758](https://www.openstreetmap.org/node/14152751758) |
| 11 | **include** | Shah's Halal Food | 49 | `restaurant` | `fully_halal` | `diet:halal=only` — exclusively halal | York Street, New Haven 06520 | [node/13570457048](https://www.openstreetmap.org/node/13570457048) |
| 12 | _your call_ | COOK 2GO | 49 | `grocery` | `halal_options` | `diet:halal=yes` — halal available, not exclusive | 1064 Chapel Street, New Haven 06510 | [node/2760039195](https://www.openstreetmap.org/node/2760039195) |
| 13 | **drop** | Harvest Wine Bar & Restaurant | 49 | `restaurant` | `halal_options` | `diet:halal=yes` — halal available, not exclusive | 1104 Chapel Street, New Haven 06510 | [node/13888879075](https://www.openstreetmap.org/node/13888879075) |
| 14 | **include** | Halal Meat and Grocery | 65 | `grocery` | `unverified` | no `diet:halal` tag; only the name implies it | 3853 Main Street, Bridgeport 06606 | [way/369786327](https://www.openstreetmap.org/way/369786327) |
| 15 | _your call_ | Tabouli and More | 65 | `restaurant` | `halal_options` | `diet:halal=yes` — halal available, not exclusive | 270 Federal Road, Brookfield 06804 | [node/11938398999](https://www.openstreetmap.org/node/11938398999) |
| 16 | **include** | Shah's Halal Food | 67 | `restaurant` | `fully_halal` | `diet:halal=only` — exclusively halal | Plumtrees Road, Danbury 06801 | [node/12600853705](https://www.openstreetmap.org/node/12600853705) |
| 17 | _your call_ | Ridgefield Organics And Specialty Market | 74 | `grocery` | `halal_options` | `diet:halal=yes` — halal available, not exclusive | 109 Danbury road, Ridgefield,ct, Ridgefield 06877 | [node/12133881061](https://www.openstreetmap.org/node/12133881061) |
| 18 | **include** | Shah's Halal Food | 79 | `restaurant` | `unverified` | no `diet:halal` tag; only the name implies it | West Cedar Street, Norwalk 06854 | [node/14099295294](https://www.openstreetmap.org/node/14099295294) |

## Rows I'd think twice about

**Mainstream retailers that merely stock halal** — real stores, correctly tagged, but a
shopper opening a *halal* map and finding Whole Foods may feel the app is padding itself.
They are legitimately `halal_options` if you want the coverage:

- Whole Foods Market (South Windsor) — closest pin to Storrs at ~16 mi
- ShopRite (Cromwell)
- Asia Supermarket (Meriden)
- COOK 2GO (New Haven)
- Ridgefield Organics And Specialty Market (Ridgefield)

**Restaurants tagged `diet:halal=yes`, scope unclear from OSM alone** — these look like
Middle Eastern / halal-leaning places, but the tag only says halal food is available, not
that the kitchen is exclusively halal. Including them as `halal_options` is honest:

- Shawarma Zone (Middletown) — next door to Shah's on Main St
- Parsley (Middletown)
- Sliders (Southington)
- Tabouli and More (Brookfield)

**Recommend dropping:**

- Harvest Wine Bar & Restaurant (New Haven) — tagged halal-friendly, but it is a wine bar.
  Listing it on a halal map cuts against the app's own stance, whatever the tag says.

## What I still owe this list

- Nothing within 15 miles of Storrs exists in OSM. The nearest is **Halal Meat & Seafoods**
  in Manchester at ~16 mi. That is a genuine gap in OSM's coverage, not a query bug — I
  confirmed it with exact-match, regex and radius queries. If you know halal spots closer
  to campus, name them and I'll add them from their own websites instead (also allowed by
  the plan) rather than inventing coordinates.
- Two hits (Shaw's Halal Food, Spacegrill) were just over the NY line in Mamaroneck /
  White Plains and are excluded.
- OpenStreetMap needs an ODbL credit on the Acknowledgements screen before this ships.
  I'll add it with the migration.


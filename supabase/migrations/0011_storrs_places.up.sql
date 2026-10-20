-- ============================================================================
-- 0011_storrs_places (UP) — four more real places on and around the UConn
-- Storrs campus, from Omar's TestFlight feedback ("more places in Storrs").
--
-- Same two-source rule as 0007/0010, no exceptions:
--   1. a real coordinate from OpenStreetMap (© OpenStreetMap contributors, ODbL),
--      the place's own node — or, where the place isn't mapped yet, its
--      building's (same as 0010); and
--   2. a halal claim published by the operator itself (or by the directory
--      quoting its management), quoted above each row with the URL.
--
-- Scope is set to what the claim actually says, never more:
--   halal_options   — some items are halal (The Coop: "Tenders are ... Halal")
--   halal_meat_only — every meat served is halal (Haven, Guac N Grill)
--   fully_halal     — the whole menu is halal and no alcohol (Little Aladdin)
-- Students refine any of this in-app through vote_store() (0005).
--
-- Considered and LEFT OUT (no published halal claim we could verify):
--   Kathmandu Kitchen & Bar — only a third-party menu copy says the lamb/goat
--     entrees use halal meat; its own site is down. Confirm with the restaurant.
--   Gansett Wraps — appears in a delivery app's "halal" category only.
--   Husky Pizza — the UConn MSA page says "the majority of the meat is halal,
--     always ask"; undated, and the shop isn't in OpenStreetMap.
--
-- ids are uuid5(DNS-namespace, "haliable:uconn:<osm ref>"), idempotent.
-- Generated 2026-10-17.
-- ============================================================================

insert into public.stores
  (id, name, category, halal_scope, address, city, state, zip, location,
   certifications, source, status, confirm_count, dispute_count)
values
  -- node/14293871567: https://www.openstreetmap.org/node/14293871567
  -- evidence: UConn Dining, The Coop page — "Tenders are gluten-free & Halal."
  --   https://dining.uconn.edu/the-coop/  (mall level of the Student Union)
  ('a45670ea-84ca-5244-bebc-8b5c0649981f', 'The Coop', 'restaurant', 'halal_options',
   'Student Union, mall level, 2110 Hillside Road', 'Storrs', 'CT', '06269',
   st_setsrid(st_makepoint(-72.2552545, 41.8074576), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- node/6491642642: https://www.openstreetmap.org/node/6491642642
  -- evidence: Haven Hot Chicken — "Haven Hot Chicken uses only 100% certified Halal
  --   chicken" https://www.havenhotchicken.com/ (Storrs is a listed location).
  -- address: 1206 Storrs Rd (Hartford Business Journal); the Daily Campus, Aug 28
  --   2026: "at the corner of Storrs Road and South Eagleville Road".
  ('3e97306b-0d5d-5053-a477-a2a31ec27b76', 'Haven Hot Chicken', 'restaurant', 'halal_meat_only',
   '1206 Storrs Road', 'Storrs', 'CT', '06268',
   st_setsrid(st_makepoint(-72.2409207, 41.8013763), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- way/773881922 (the 1244 Storrs Road building): https://www.openstreetmap.org/way/773881922
  -- Guac N Grill itself is not mapped yet; it took over the Chang's Garden unit.
  -- evidence: The Connecticut Scoop — "crafted with Zabiha halal meats"; the Daily
  --   Campus, Apr 13 2026 — "All meats are Zabiha Halal certified"; the Daily
  --   Campus, Aug 28 2026 — open: "Guac 'n Grill, a halal-certified sit-down
  --   Mexican spot". No certifier is named by the restaurant, so none is listed.
  --   https://www.theconnecticutscoop.com/all-tolland-county-posts/storrs-scoop-guac-n-grill-halal-mexican-food-coming-to-storrs
  --   https://dailycampus.com/2026/08/28/demystifying-downtown-where-to-grab-a-bite/
  ('1e572d38-1147-500e-9ca8-d2fa863a2207', 'Guac N Grill', 'restaurant', 'halal_meat_only',
   '1244 Storrs Road', 'Storrs', 'CT', '06268',
   st_setsrid(st_makepoint(-72.2423434, 41.8034998), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- node/12004732531: https://www.openstreetmap.org/node/12004732531
  -- evidence: Zabihah listing — "The owners are Muslim and have confirmed its halal
  --   status", marked "Fully halal" and "No alcohol allowed"; management note:
  --   "All the Food Halal and home made."
  --   https://www.zabihah.com/restaurants/cb728957-7767-11ef-95ae-6045bdeb9f57/little-aladdin-mansfield-ct
  ('83694fda-b7ac-58b6-91ea-d80c3ac82b32', 'Little Aladdin Mediterranean Grill', 'restaurant', 'fully_halal',
   'University Plaza, 1232 Storrs Road', 'Storrs', 'CT', '06268',
   st_setsrid(st_makepoint(-72.2416630, 41.8030160), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0)
on conflict (id) do nothing;

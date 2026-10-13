-- ============================================================================
-- 0007_real_stores (UP) — replace the five invented demo stores from 0002 with
-- the places on the UConn Storrs campus that actually serve halal food.
--
-- Scope is the campus deliberately: a student opens the app where they are and
-- sees where they can eat today, rather than a scatter of businesses an hour away.
--
-- EVERY row required two independent things, and no row is here without both:
--   1. a real coordinate from OpenStreetMap (© OpenStreetMap contributors, ODbL —
--      credited in-app on the Acknowledgements screen, as ODbL requires), and
--   2. a halal claim published by UConn Dining Services itself, quoted in the
--      comment above the row. Sources:
--        https://dining.uconn.edu/locations/
--        https://dining.uconn.edu/uc-cafes/
--        https://dining.uconn.edu/ramadan
--
-- All five are halal_options, not fully_halal: these are halal stations and halal
-- menu items inside facilities that also serve non-halal food. Calling any of them
-- fully_halal would overstate what UConn actually claims. Students refine this
-- in-app through vote_store() (migration 0005).
--
-- ids are uuid5(DNS-namespace, "haliable:uconn:<osm ref>") so re-running changes
-- nothing and the rollback deletes exactly these rows.
--
-- Known gap: UConn lists five cafes; CrossRoads Cafe and Market Cafe are not in
-- OpenStreetMap and are omitted rather than given an approximate pin.
-- Generated 2026-10-13.
-- ============================================================================

-- 1) Remove the invented demo rows (same ids as 0002). store_votes cascades.
delete from public.stores
where id in (
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000002',
  '00000000-0000-4000-8000-000000000003',
  '00000000-0000-4000-8000-000000000004',
  '00000000-0000-4000-8000-000000000005'
);

-- 2) Insert the campus halal locations.
insert into public.stores
  (id, name, category, halal_scope, address, city, state, zip, location,
   certifications, source, status, confirm_count, dispute_count)
values
  -- relation/13257151: https://www.openstreetmap.org/relation/13257151
  -- evidence: UConn Dining: "Halal (Muslim) menu offerings will be available Monday through Friday." Ramadan page: "meals will be at the Halal station at Gelfenbien and South."
  ('7acb9992-fc26-5872-8c33-f88fbfbdd6bb', 'Gelfenbien Commons (Towers) Dining Hall', 'restaurant', 'halal_options',
   'Alumni Drive', 'Storrs', 'CT', '06269',
   st_setsrid(st_makepoint(-72.2544209, 41.8134363), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- way/233918996: https://www.openstreetmap.org/way/233918996
  -- evidence: UConn Dining: South offers "Halal, gluten-friendly, vegetarian, and vegan options at every meal." Ramadan page names South as one of the two Halal stations.
  ('6c56ab10-cf4a-5a5f-947b-27316df7973b', 'South Dining Hall (Rome Commons)', 'restaurant', 'halal_options',
   '626 Gilbert Road Ext', 'Storrs', 'CT', '06269',
   st_setsrid(st_makepoint(-72.2485279, 41.8039325), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- node/5980545724: https://www.openstreetmap.org/node/5980545724
  -- evidence: UConn Dining cafes: "Vegan, kosher, and halal menu items are offered daily (while supplies last)."
  ('c9a37656-877f-59ab-b9c6-9c2bbdab1089', 'The Beanery Cafe', 'cafe', 'halal_options',
   'Monteith Building, Fairfield Way', 'Storrs', 'CT', '06269',
   st_setsrid(st_makepoint(-72.2529506, 41.8084963), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- node/5980545705: https://www.openstreetmap.org/node/5980545705
  -- evidence: UConn Dining cafes: "Vegan, kosher, and halal menu items are offered daily (while supplies last)."
  ('f1c0d43f-52df-5ff6-ba0e-f9333d9c7cc8', 'Bookworms Cafe', 'cafe', 'halal_options',
   'Homer Babbidge Library, Fairfield Way', 'Storrs', 'CT', '06269',
   st_setsrid(st_makepoint(-72.2517702, 41.8063376), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- node/12187339732: https://www.openstreetmap.org/node/12187339732
  -- evidence: UConn Dining cafes: "Vegan, kosher, and halal menu items are offered daily (while supplies last)."
  ('3b3ecc58-8762-5cfa-a010-39828723b203', 'nanoByte Cafe', 'cafe', 'halal_options',
   'Information Technologies Engineering Building', 'Storrs', 'CT', '06269',
   st_setsrid(st_makepoint(-72.2593398, 41.8077349), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0)
on conflict (id) do nothing;

-- ============================================================================
-- 0010_campus_cafes (UP) — the two UConn cafes 0007 had to leave out.
--
-- 0007 omitted CrossRoads Cafe and Market Cafe because neither cafe is mapped in
-- OpenStreetMap, and it refused an approximate pin. Both BUILDINGS are mapped, and
-- UConn Dining publishes which building (and floor) each cafe is in, so each row
-- uses its building's OSM coordinate — still a real coordinate, never a guess.
-- Same two-source rule as 0007: OSM coordinate (© OpenStreetMap contributors,
-- ODbL) + a halal claim published by UConn Dining itself.
--   https://dining.uconn.edu/uc-cafes/
--
-- halal_options, not fully_halal — same reasoning as 0007.
-- ids are uuid5(DNS-namespace, "haliable:uconn:<osm ref>"), idempotent.
-- Generated 2026-10-16.
-- ============================================================================

insert into public.stores
  (id, name, category, halal_scope, address, city, state, zip, location,
   certifications, source, status, confirm_count, dispute_count)
values
  -- way/31529222 (Wilbur Cross Building): https://www.openstreetmap.org/way/31529222
  -- location: UConn Dining — main floor of the Wilbur Cross Building, next to the Information Center.
  -- evidence: UConn Dining cafes: "Vegan, kosher, and halal menu items are offered daily (while supplies last)."
  ('30ea9160-74f2-53c2-a2f8-f3df28a3a5ce', 'CrossRoads Cafe', 'cafe', 'halal_options',
   'Wilbur Cross Building, 233 Glenbrook Road', 'Storrs', 'CT', '06269',
   st_setsrid(st_makepoint(-72.2517556, 41.8092063), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- way/31545256 (Student Union): https://www.openstreetmap.org/way/31545256
  -- location: UConn Dining — lower level of the Student Union, by Union Street Market.
  -- evidence: UConn Dining cafes: "Vegan, kosher, and halal menu items are offered daily (while supplies last)."
  ('cbc6c314-b299-5272-adec-0f5faaa2d879', 'Market Cafe', 'cafe', 'halal_options',
   'Student Union, 2110 Hillside Road', 'Storrs', 'CT', '06269',
   st_setsrid(st_makepoint(-72.2547452, 41.8071112), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0)
on conflict (id) do nothing;

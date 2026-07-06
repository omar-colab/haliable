-- ============================================================================
-- 0002_seed_stores (UP) — migrate the five demo stores that used to be hardcoded
-- in StoreService.seed(...) into the table. Marked source='seed', status='approved'
-- so they render on the map immediately. Anchored on the app's NYC fallback
-- coordinate (40.7308, -73.9975) using the same offsets the old seed used, so the
-- demo cluster looks identical to before.
--
-- Idempotent (fixed UUIDs + on conflict do nothing); additive — never deletes
-- community data. Rolled back by id in the .down.sql.
-- ============================================================================

insert into public.stores
  (id, name, category, halal_scope, address, city, state, zip, location,
   certifications, source, status, confirm_count, dispute_count)
values
  ('00000000-0000-4000-8000-000000000001', 'Al-Noor Halal Market', 'grocery',
   'fully_halal', '123 Sample St', 'Sampletown', 'NY', '10001',
   st_setsrid(st_makepoint(-73.9945, 40.7348), 4326)::geography,
   '{"HMS"}', 'seed', 'approved', 12, 0),

  ('00000000-0000-4000-8000-000000000002', 'Zabiha Meats & Deli', 'butcher',
   'halal_meat_only', '123 Sample St', 'Sampletown', 'NY', '10001',
   st_setsrid(st_makepoint(-73.9955, 40.7258), 4326)::geography,
   '{"HFSAA"}', 'seed', 'approved', 9, 0),

  ('00000000-0000-4000-8000-000000000003', 'Crescent Kitchen', 'restaurant',
   'halal_options', '123 Sample St', 'Sampletown', 'NY', '10001',
   st_setsrid(st_makepoint(-74.0015, 40.7328), 4326)::geography,
   '{}', 'seed', 'approved', 7, 0),

  ('00000000-0000-4000-8000-000000000004', 'Barakah Bakery', 'bakery',
   'fully_halal', '123 Sample St', 'Sampletown', 'NY', '10001',
   st_setsrid(st_makepoint(-74.0005, 40.7278), 4326)::geography,
   '{}', 'seed', 'approved', 5, 0),

  ('00000000-0000-4000-8000-000000000005', 'Salam Cafe', 'cafe',
   'halal_options', '123 Sample St', 'Sampletown', 'NY', '10001',
   st_setsrid(st_makepoint(-73.9965, 40.7368), 4326)::geography,
   '{}', 'seed', 'approved', 4, 0)
on conflict (id) do nothing;

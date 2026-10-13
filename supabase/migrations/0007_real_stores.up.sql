-- ============================================================================
-- 0007_real_stores (UP) — replace the five invented demo stores from 0002 with
-- real Connecticut halal businesses.
--
-- Source: OpenStreetMap via the Overpass API, 2026-10-13. Data © OpenStreetMap
-- contributors, licensed under the Open Database License (ODbL). The app credits
-- OpenStreetMap on its Acknowledgements screen, which ODbL requires.
-- Addresses were filled in from Nominatim reverse geocoding where OSM had no
-- addr:* tags. Every row traces to the OSM object named in its comment; the full
-- review table with evidence per row is docs/stores-candidates.md.
--
-- halal_scope is mapped conservatively, per "report, don't rule":
--   diet:halal=only          -> fully_halal
--   diet:halal=yes           -> halal_options   (halal available, not exclusive)
--   no tag, "Halal" in name  -> unverified      (a name is a claim, not a source)
-- Users refine these in-app through vote_store() (migration 0005).
--
-- ids are uuid5(DNS-namespace, "haliable:osm:<type>/<id>") so re-running changes
-- nothing and the rollback can delete exactly these rows.
-- Ordered by distance from Storrs/UConn, nearest first.
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

-- 2) Insert the real stores.
insert into public.stores
  (id, name, category, halal_scope, address, city, state, zip, location,
   certifications, source, status, confirm_count, dispute_count)
values
  -- 16 mi from Storrs · https://www.openstreetmap.org/node/5337895492 · no diet:halal tag
  ('d73d57b0-a568-5140-9e35-ce9d2494d44f', 'Halal Meat & Seafoods', 'supermarket', 'unverified',
   'Tolland Turnpike', 'Manchester', 'CT', '06042',
   st_setsrid(st_makepoint(-72.5526291, 41.7978658), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- 16 mi from Storrs · https://www.openstreetmap.org/node/11088351797 · diet:halal=yes
  ('6a0edebb-716b-5708-8e4c-1240066c269a', 'Whole Foods Market', 'supermarket', 'halal_options',
   'Holly Drive', 'South Windsor', 'CT', '06074',
   st_setsrid(st_makepoint(-72.5556307, 41.8153918), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- 26 mi from Storrs · https://www.openstreetmap.org/node/6503446086 · diet:halal=yes
  ('f6bfa86c-5535-5181-a6c9-65aedf433f42', 'ShopRite', 'supermarket', 'halal_options',
   '45 Shunpike Road', 'Cromwell', 'CT', '06416',
   st_setsrid(st_makepoint(-72.6782943, 41.6047369), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- 27 mi from Storrs · https://www.openstreetmap.org/node/2954479168 · no diet:halal tag
  ('1f6bcadb-0c87-54ca-9b9b-c4aa3029b690', 'Middletown Halal Grill and Pizza', 'restaurant', 'unverified',
   '570 Main Street', 'Middletown', 'CT', '06457',
   st_setsrid(st_makepoint(-72.6515308, 41.5638619), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- 27 mi from Storrs · https://www.openstreetmap.org/node/13356076209 · diet:halal=yes
  ('670fda53-ed55-5cb8-852f-d3f77fc3350c', 'Shawarma Zone', 'restaurant', 'halal_options',
   '560 Main Street', 'Middletown', 'CT', '06457',
   st_setsrid(st_makepoint(-72.6514601, 41.5637331), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- 27 mi from Storrs · https://www.openstreetmap.org/way/661906623 · diet:halal=only
  ('857df1e7-4691-5fb2-a251-533ab4b292bc', 'Shah''s Halal Food', 'restaurant', 'fully_halal',
   '344 Main Street', 'Middletown', 'CT', '06457',
   st_setsrid(st_makepoint(-72.6498044, 41.5611182), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- 27 mi from Storrs · https://www.openstreetmap.org/node/6196878552 · diet:halal=yes
  ('9caf8951-e22f-565b-abf9-305b7e15e88b', 'Parsley', 'restaurant', 'halal_options',
   '324 Main Street', 'Middletown', 'CT', '06457',
   st_setsrid(st_makepoint(-72.6496730, 41.5608567), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- 28 mi from Storrs · https://www.openstreetmap.org/node/9446184897 · diet:halal=yes
  ('4aaaa52c-0d10-5c13-a721-5c854ba63056', 'Halal Munchies', 'restaurant', 'halal_options',
   '690 Washington Street', 'Middletown', 'CT', '06457',
   st_setsrid(st_makepoint(-72.6751978, 41.5549338), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- 31 mi from Storrs · https://www.openstreetmap.org/node/9724238859 · diet:halal=yes
  ('68b0ce40-8902-5717-af36-32b351f5e3a6', 'Asia Supermarket', 'supermarket', 'halal_options',
   'North Broad Street', 'Meriden', 'CT', '06450',
   st_setsrid(st_makepoint(-72.7691712, 41.5744128), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- 37 mi from Storrs · https://www.openstreetmap.org/node/14152751758 · diet:halal=yes
  ('88f5ccf9-4e80-527e-a926-bfe7cd0bab1e', 'Sliders', 'restaurant', 'halal_options',
   'Mulberry Street', 'Southington', 'CT', '06479',
   st_setsrid(st_makepoint(-72.8952250, 41.5739883), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- 49 mi from Storrs · https://www.openstreetmap.org/node/13570457048 · diet:halal=only
  ('5b6aaa03-3c51-5f68-9068-c572085b21db', 'Shah''s Halal Food', 'restaurant', 'fully_halal',
   'York Street', 'New Haven', 'CT', '06520',
   st_setsrid(st_makepoint(-72.9298684, 41.3111482), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- 49 mi from Storrs · https://www.openstreetmap.org/node/2760039195 · diet:halal=yes
  ('e78f5ff3-3109-5215-b47e-3c7062c5e3e9', 'COOK 2GO', 'grocery', 'halal_options',
   '1064 Chapel Street', 'New Haven', 'CT', '06510',
   st_setsrid(st_makepoint(-72.9302103, 41.3077632), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- 65 mi from Storrs · https://www.openstreetmap.org/way/369786327 · no diet:halal tag
  ('a5c97b89-5d70-5231-ba9e-475c51241d31', 'Halal Meat and Grocery', 'grocery', 'unverified',
   '3853 Main Street', 'Bridgeport', 'CT', '06606',
   st_setsrid(st_makepoint(-73.2117622, 41.2133400), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- 65 mi from Storrs · https://www.openstreetmap.org/node/11938398999 · diet:halal=yes
  ('9abaf601-db30-5d89-9a3c-7ccb7d9efe11', 'Tabouli and More', 'restaurant', 'halal_options',
   '270 Federal Road', 'Brookfield', 'CT', '06804',
   st_setsrid(st_makepoint(-73.4045808, 41.4465702), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- 67 mi from Storrs · https://www.openstreetmap.org/node/12600853705 · diet:halal=only
  ('f08c4427-b1ca-564c-8e97-5d97daa28c67', 'Shah''s Halal Food', 'restaurant', 'fully_halal',
   'Plumtrees Road', 'Danbury', 'CT', '06801',
   st_setsrid(st_makepoint(-73.4183867, 41.4051724), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- 74 mi from Storrs · https://www.openstreetmap.org/node/12133881061 · diet:halal=yes
  ('70feb9dd-06c1-5389-bdf8-3e8b11e8ca60', 'Ridgefield Organics And Specialty Market', 'grocery', 'halal_options',
   '109 Danbury road, Ridgefield,ct', 'Ridgefield', 'CT', '06877',
   st_setsrid(st_makepoint(-73.4940760, 41.2933733), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0),

  -- 79 mi from Storrs · https://www.openstreetmap.org/node/14099295294 · no diet:halal tag
  ('a4757ff4-df4e-5698-b6b8-b02cd9a559e9', 'Shah''s Halal Food', 'restaurant', 'unverified',
   'West Cedar Street', 'Norwalk', 'CT', '06854',
   st_setsrid(st_makepoint(-73.4395055, 41.1023796), 4326)::geography,
   '{}', 'seed', 'approved', 0, 0)
on conflict (id) do nothing;

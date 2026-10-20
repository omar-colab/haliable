-- ============================================================================
-- 0011_storrs_places (DOWN) — remove exactly the four rows 0011 added.
-- ============================================================================

delete from public.stores
where id in (
  'a45670ea-84ca-5244-bebc-8b5c0649981f',  -- The Coop
  '3e97306b-0d5d-5053-a477-a2a31ec27b76',  -- Haven Hot Chicken
  '1e572d38-1147-500e-9ca8-d2fa863a2207',  -- Guac N Grill
  '83694fda-b7ac-58b6-91ea-d80c3ac82b32'   -- Little Aladdin Mediterranean Grill
);

-- ============================================================================
-- 0010_campus_cafes (DOWN) — remove exactly the two rows 0010 added.
-- ============================================================================

delete from public.stores
where id in (
  '30ea9160-74f2-53c2-a2f8-f3df28a3a5ce',  -- CrossRoads Cafe
  'cbc6c314-b299-5272-adec-0f5faaa2d879'   -- Market Cafe
);

-- ============================================================================
-- 0001_stores_atlas (DOWN) — reverse 0001_stores_atlas.up.sql.
-- Drops ONLY what the up migration created. Leaves the postgis/pgcrypto
-- extensions in place (other features may rely on them).
-- ============================================================================

drop function if exists public.stores_nearby(double precision, double precision, double precision, text);

drop policy if exists "read approved stores" on public.stores;

drop table if exists public.stores;

drop type if exists store_source;
drop type if exists store_status;
drop type if exists store_category;
drop type if exists halal_scope;

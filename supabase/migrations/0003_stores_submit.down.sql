-- ============================================================================
-- 0003_stores_submit (DOWN) — reverse 0003_stores_submit.up.sql.
-- ============================================================================

drop function if exists public.submit_store(
  text, text, text, text, text, text, text, double precision, double precision
);

drop policy if exists "read own submissions" on public.stores;

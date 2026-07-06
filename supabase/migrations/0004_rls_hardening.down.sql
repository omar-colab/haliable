-- ============================================================================
-- 0004_rls_hardening (DOWN) — FAIL-CLOSED rollback.
--
-- Rolling back a security migration must never OPEN access. We drop the policies
-- this migration asserted but LEAVE RLS enabled — so the tables fall back to
-- deny-all (no policy = no access) rather than exposing data. Re-apply the up
-- migration (or 0001/0003/supabase-setup) to restore normal access.
-- ============================================================================

drop policy if exists "read approved stores"  on public.stores;
drop policy if exists "read own submissions"  on public.stores;
drop policy if exists "insert own review"     on public.review_requests;
drop policy if exists "read own reviews"      on public.review_requests;

-- RLS intentionally left ENABLED on both tables (deny-all until re-applied).

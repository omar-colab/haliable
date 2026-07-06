-- ============================================================================
-- 0004_rls_hardening (UP) — make the Row-Level Security posture EXPLICIT and
-- consolidated in one auditable place. The individual policies already exist
-- (stores from 0001/0003, review_requests from supabase-setup.sql); this migration
-- (re)asserts the complete, canonical set so the whole security surface can be
-- reviewed in a single file, and guarantees RLS is enabled everywhere.
--
-- Posture (the four invariants the test matrix in supabase/tests/rls_matrix.sql
-- proves):
--   1. anon/public may SELECT only APPROVED stores.
--   2. an authenticated user may SELECT their OWN rows (any status) — and only
--      their own; never another user's pending submission.
--   3. there is NO user INSERT/UPDATE/DELETE policy on stores → a user cannot
--      self-approve (change status) or write directly; the ONLY write path is the
--      SECURITY DEFINER submit_store() RPC, which forces status='pending',
--      source='community', submitted_by=auth.uid().
--   4. review_requests: a user may INSERT/SELECT only their OWN rows; there is no
--      user UPDATE policy → a user cannot change a verdict. Verdicts/approvals are
--      service-role/admin only.
--
-- Reversible: see 0004_rls_hardening.down.sql (intentionally FAIL-CLOSED).
-- ============================================================================

-- 1) Force RLS on (idempotent) -----------------------------------------------
alter table public.stores          enable row level security;
alter table public.review_requests enable row level security;

-- 2) stores policies (canonical restatement) ---------------------------------
drop policy if exists "read approved stores" on public.stores;
create policy "read approved stores" on public.stores
  for select
  using (status = 'approved');

drop policy if exists "read own submissions" on public.stores;
create policy "read own submissions" on public.stores
  for select to authenticated
  using (submitted_by = auth.uid());

-- NOTE: deliberately NO insert/update/delete policy on public.stores. Under RLS,
-- the absence of a permissive policy = denied. Writes go only through
-- submit_store(); status changes (approval) require the service-role key.

-- 3) review_requests policies (canonical restatement) ------------------------
drop policy if exists "insert own review" on public.review_requests;
create policy "insert own review" on public.review_requests
  for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "read own reviews" on public.review_requests;
create policy "read own reviews" on public.review_requests
  for select to authenticated
  using (auth.uid() = user_id);

-- NOTE: deliberately NO user UPDATE policy on review_requests → a user cannot set
-- their own verdict. Reviewers write verdicts with the service-role key.

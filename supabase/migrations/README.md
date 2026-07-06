# Supabase migrations

Reversible, numbered SQL migrations for the Haliable backend. Each migration is a
pair: `NNNN_name.up.sql` (apply) and `NNNN_name.down.sql` (roll back). Run them by
hand in the Supabase dashboard → SQL Editor, in order, the same way `supabase-setup.sql`
is run.

Conventions (match the existing `supabase-setup.sql` at the repo root):
- lowercase SQL keywords, `create … if not exists`, idempotent where possible.
- enums created with a guarded `do $$ … exception when duplicate_object …` block.
- Row-Level Security is declared alongside the table it protects.
- `.down.sql` reverses ONLY what its `.up.sql` created. It never touches data or
  objects owned by another migration (e.g. nothing here drops `review_requests`).
- Seed data lives in its own migration and is removed by id on rollback — community
  rows are never hard-deleted.

## History
- The photo manual-review backend (`review_requests`, `review-photos`) predates this
  folder and still lives in the root `supabase-setup.sql` (run that first).
- `0001_stores_atlas` — Store Atlas: `stores` table (PostGIS), enums, RLS read policy,
  and the `stores_nearby` spatial RPC.
- `0002_seed_stores` — migrates the five demo stores formerly hardcoded in
  `StoreService` into the table as `source='seed', status='approved'`.
- `0003_stores_submit` — community submit: own-pending RLS read + the validated,
  deduped `submit_store()` write RPC.
- `0004_rls_hardening` — consolidates/asserts the full RLS posture for `stores` +
  `review_requests` in one auditable file (fail-closed down).
- `0005_store_votes` — confirm/dispute votes: `store_votes` table (one per user) +
  the `vote_store()` RPC that recomputes a store's confirm/dispute counts.

Tests: `supabase/tests/rls_matrix.sql` proves the RLS invariants (run after 0004).

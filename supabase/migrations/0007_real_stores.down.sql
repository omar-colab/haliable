-- ============================================================================
-- 0007_real_stores (DOWN) — remove the UConn campus rows by id. Reverses only what
-- 0007 did, per supabase/migrations/README.md. Community submissions are untouched.
-- The five demo rows from 0002 are not recreated; re-run 0002_seed_stores.up.sql
-- if you genuinely want that cluster back.
-- ============================================================================

delete from public.stores
where id in (
  '7acb9992-fc26-5872-8c33-f88fbfbdd6bb',  -- Gelfenbien Commons (Towers) Dining Hall
  '6c56ab10-cf4a-5a5f-947b-27316df7973b',  -- South Dining Hall (Rome Commons)
  'c9a37656-877f-59ab-b9c6-9c2bbdab1089',  -- The Beanery Cafe
  'f1c0d43f-52df-5ff6-ba0e-f9333d9c7cc8',  -- Bookworms Cafe
  '3b3ecc58-8762-5cfa-a010-39828723b203'  -- nanoByte Cafe
);

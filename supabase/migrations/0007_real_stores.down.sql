-- ============================================================================
-- 0007_real_stores (DOWN) — remove the real stores by id and restore the five
-- demo rows from 0002, so rolling back lands exactly where 0006 left off.
-- Community submissions are never touched.
-- ============================================================================

delete from public.stores
where id in (
  'd73d57b0-a568-5140-9e35-ce9d2494d44f',  -- Halal Meat & Seafoods
  '6a0edebb-716b-5708-8e4c-1240066c269a',  -- Whole Foods Market
  'f6bfa86c-5535-5181-a6c9-65aedf433f42',  -- ShopRite
  '1f6bcadb-0c87-54ca-9b9b-c4aa3029b690',  -- Middletown Halal Grill and Pizza
  '670fda53-ed55-5cb8-852f-d3f77fc3350c',  -- Shawarma Zone
  '857df1e7-4691-5fb2-a251-533ab4b292bc',  -- Shah's Halal Food
  '9caf8951-e22f-565b-abf9-305b7e15e88b',  -- Parsley
  '4aaaa52c-0d10-5c13-a721-5c854ba63056',  -- Halal Munchies
  '68b0ce40-8902-5717-af36-32b351f5e3a6',  -- Asia Supermarket
  '88f5ccf9-4e80-527e-a926-bfe7cd0bab1e',  -- Sliders
  '5b6aaa03-3c51-5f68-9068-c572085b21db',  -- Shah's Halal Food
  'e78f5ff3-3109-5215-b47e-3c7062c5e3e9',  -- COOK 2GO
  'a5c97b89-5d70-5231-ba9e-475c51241d31',  -- Halal Meat and Grocery
  '9abaf601-db30-5d89-9a3c-7ccb7d9efe11',  -- Tabouli and More
  'f08c4427-b1ca-564c-8e97-5d97daa28c67',  -- Shah's Halal Food
  '70feb9dd-06c1-5389-bdf8-3e8b11e8ca60',  -- Ridgefield Organics And Specialty Market
  'a4757ff4-df4e-5698-b6b8-b02cd9a559e9'  -- Shah's Halal Food
);

-- The five demo rows from 0002 are NOT recreated here: this file reverses only what
-- 0007 did, per the convention in supabase/migrations/README.md. If you genuinely want
-- the old demo cluster back, re-run 0002_seed_stores.up.sql afterwards.

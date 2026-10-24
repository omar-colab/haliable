 -- ============================================================================
-- RLS test matrix for the Store Atlas + reviews.
--
-- HOW TO RUN: paste the whole file into the Supabase SQL Editor and Run it (after
-- applying migrations 0001–0004). It simulates anon + two authenticated users by
-- switching role and setting request.jwt.claims, asserts each security invariant,
-- and ROLLS BACK at the end — it creates two throwaway users + rows and leaves
-- NOTHING behind. On success you'll see "✅ ALL RLS TESTS PASSED". On any failure
-- it aborts at the first failing assertion with a clear FAIL message.
--
-- Invariants proven:
--   1. anon may read APPROVED stores only (no pending leak).
--   2. an authenticated user may read approved + their OWN rows, never another
--      user's pending submission.
--   3. a user CANNOT self-approve (UPDATE status is denied → 0 rows).
--   4. a user CANNOT write stores directly (no INSERT policy → RLS blocks).
--   5. a user CAN delete their own review photos (account deletion depends on it).
-- ============================================================================

begin;

-- Throwaway test users (FK target for submitted_by). Rolled back at the end.
insert into auth.users
  (instance_id, id, aud, role, email, encrypted_password,
   email_confirmed_at, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000',
   'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   'authenticated','authenticated','rls-a@test.dev','', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000000',
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
   'authenticated','authenticated','rls-b@test.dev','', now(), now(), now());

-- Seed rows as service-role (bypasses RLS): one APPROVED, one PENDING owned by B.
insert into public.stores
  (id, name, halal_scope, location, source, submitted_by, status)
values
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'RLS Approved', 'fully_halal',
   st_setsrid(st_makepoint(-73.99, 40.73), 4326)::geography, 'seed', null, 'approved'),
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'RLS Pending B', 'fully_halal',
   st_setsrid(st_makepoint(-73.99, 40.73), 4326)::geography, 'community',
   'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'pending');

-- ── TEST 1: anon reads approved only ────────────────────────────────────────
set local role anon;
do $$ begin
  if (select count(*) from public.stores
        where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc') <> 1 then
    raise exception 'FAIL 1a: anon cannot read an APPROVED store';
  end if;
  if (select count(*) from public.stores
        where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd') <> 0 then
    raise exception 'FAIL 1b: anon CAN read a PENDING store (leak!)';
  end if;
end $$;
reset role;

-- ── TEST 2: user A reads approved + own, NOT user B's pending ────────────────
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}';
do $$ begin
  if (select count(*) from public.stores
        where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc') <> 1 then
    raise exception 'FAIL 2a: user A cannot read an APPROVED store';
  end if;
  if (select count(*) from public.stores
        where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd') <> 0 then
    raise exception 'FAIL 2b: user A CAN read user B''s pending row (leak!)';
  end if;
end $$;
reset role;

-- ── TEST 3: user B reads their OWN pending row ──────────────────────────────
set local role authenticated;
set local request.jwt.claims = '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}';
do $$ begin
  if (select count(*) from public.stores
        where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd') <> 1 then
    raise exception 'FAIL 3: user B cannot read their OWN pending row';
  end if;
end $$;
reset role;

-- ── TEST 4: user A cannot self-approve (UPDATE denied → 0 rows) ──────────────
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}';
do $$
declare n int;
begin
  update public.stores set status = 'approved'
    where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  get diagnostics n = row_count;
  if n <> 0 then
    raise exception 'FAIL 4: user A self-approved % row(s) (should be 0)', n;
  end if;
end $$;
reset role;

-- ── TEST 5: user A cannot INSERT a store directly (no INSERT policy) ─────────
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}';
do $$
begin
  begin
    insert into public.stores (name, halal_scope, location, source, submitted_by, status)
    values ('Sneaky Direct Insert', 'fully_halal',
            st_setsrid(st_makepoint(-73.99, 40.73), 4326)::geography,
            'community', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'approved');
    raise exception 'FAIL 5: direct INSERT SUCCEEDED (should be blocked by RLS)';
  exception
    when insufficient_privilege then null;  -- expected: RLS blocks the write
  end;
end $$;
reset role;

-- ── TEST 6: users can delete their OWN review photos ─────────────────────────
-- Account deletion removes {uid}/… through the Storage API; with no DELETE policy
-- that call deletes nothing and reports no error. Checked in the catalog because
-- Storage blocks direct SQL deletes on storage.objects.
do $$ begin
  if not exists (
    select 1 from pg_policies
     where schemaname = 'storage' and tablename = 'objects'
       and cmd = 'DELETE' and 'authenticated' = any(roles)
       and qual like '%review-photos%' and qual like '%auth.uid()%') then
    raise exception 'FAIL 6: no DELETE policy for own review-photos (account deletion leaves photos)';
  end if;
end $$;

-- ── TEST 7: research bot table (0017) — public read, no public writes ──
do $$ begin
  if to_regclass('public.ingredient_research') is null then
    raise notice 'skip 7: 0017 not applied';
    return;
  end if;
  if has_table_privilege('anon', 'public.ingredient_research', 'INSERT')
     or has_table_privilege('anon', 'public.ingredient_research', 'UPDATE')
     or has_table_privilege('authenticated', 'public.ingredient_research', 'INSERT')
     or has_table_privilege('authenticated', 'public.ingredient_research', 'UPDATE')
     or has_table_privilege('authenticated', 'public.ingredient_research', 'DELETE') then
    raise exception 'FAIL 7a: the app can write ingredient_research (only the Edge Function may)';
  end if;
  if has_column_privilege('anon', 'public.ingredient_research', 'summary', 'SELECT') then
    raise exception 'FAIL 7b: anon can read the model summary (it is for Omar only)';
  end if;
  if not has_column_privilege('anon', 'public.ingredient_research', 'sources', 'SELECT') then
    raise exception 'FAIL 7c: anon cannot read research results (the app needs them)';
  end if;
end $$;

do $$ begin raise notice '✅ ALL RLS TESTS PASSED'; end $$;

rollback;

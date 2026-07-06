-- ============================================================================
-- 0005_store_votes (UP) — community confirm/dispute votes on a store.
--   • store_votes: ONE vote per (store, user); re-voting updates it.
--   • vote_store() RPC: the only write path — auth-gated, validates the vote,
--     allows votes only on APPROVED stores, upserts the user's vote, recomputes
--     stores.confirm_count / dispute_count, and returns the fresh counts.
-- Reversible: see 0005_store_votes.down.sql.
-- ============================================================================

create table if not exists public.store_votes (
  id         uuid primary key default gen_random_uuid(),
  store_id   uuid not null references public.stores(id)   on delete cascade,
  user_id    uuid not null references auth.users(id)      on delete cascade,
  vote       text not null check (vote in ('confirm','dispute')),
  created_at timestamptz not null default now(),
  unique (store_id, user_id)
);

create index if not exists store_votes_store_idx on public.store_votes(store_id);

-- RLS: a user may read their OWN votes (so the UI can show their current choice).
-- There is NO insert/update/delete policy — writes go only through vote_store().
alter table public.store_votes enable row level security;
grant select on public.store_votes to authenticated;

drop policy if exists "read own votes" on public.store_votes;
create policy "read own votes" on public.store_votes
  for select to authenticated
  using (user_id = auth.uid());

create or replace function public.vote_store(in_store_id uuid, in_vote text)
returns table (confirm_count int, dispute_count int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_c   int;
  v_d   int;
begin
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;
  if in_vote not in ('confirm','dispute') then
    raise exception 'invalid vote' using errcode = '22023';
  end if;
  if not exists (select 1 from public.stores
                 where id = in_store_id and status = 'approved') then
    raise exception 'store not found' using errcode = 'P0002';
  end if;

  insert into public.store_votes (store_id, user_id, vote)
  values (in_store_id, v_uid, in_vote)
  on conflict (store_id, user_id)
  do update set vote = excluded.vote, created_at = now();

  select count(*) filter (where vote = 'confirm'),
         count(*) filter (where vote = 'dispute')
    into v_c, v_d
    from public.store_votes
   where store_id = in_store_id;

  update public.stores
     set confirm_count = v_c, dispute_count = v_d
   where id = in_store_id;

  confirm_count := v_c;
  dispute_count := v_d;
  return next;
end;
$$;

grant execute on function public.vote_store(uuid, text) to authenticated;

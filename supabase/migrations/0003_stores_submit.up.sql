-- ============================================================================
-- 0003_stores_submit (UP) — community submit write path.
--   • own-submission read policy (submitter sees their pending; public does not)
--   • submit_store() RPC: server-side validation + spatial dedupe, then inserts a
--     pending/community row owned by auth.uid(). This is the ONLY write path —
--     there is deliberately no INSERT policy, so every write is validated here.
-- Reversible: see 0003_stores_submit.down.sql.
-- ============================================================================

-- 1) Submitter can read their OWN rows (any status), in addition to the public
--    "approved-only" policy from 0001. RLS policies are OR'd, so anon still sees
--    only approved; a pending row is visible to its submitter alone.
drop policy if exists "read own submissions" on public.stores;
create policy "read own submissions" on public.stores
  for select to authenticated
  using (submitted_by = auth.uid());

-- 2) The validated, deduped write path.
create or replace function public.submit_store(
  in_name        text,
  in_category    text,
  in_halal_scope text,
  in_address     text,
  in_city        text,
  in_state       text,
  in_zip         text,
  in_lat         double precision,
  in_lng         double precision
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_point geography := st_setsrid(st_makepoint(in_lng, in_lat), 4326)::geography;
  v_dup   uuid;
  v_id    uuid;
begin
  -- auth gate
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;

  -- server-side validation (mirrors the client checks; never trusts the client)
  if in_name is null or length(btrim(in_name)) < 2 then
    raise exception 'invalid name' using errcode = '22023';
  end if;
  if in_lat is null or in_lng is null
     or in_lat < -90 or in_lat > 90 or in_lng < -180 or in_lng > 180
     or (abs(in_lat) < 0.0001 and abs(in_lng) < 0.0001) then
    raise exception 'invalid coordinates' using errcode = '22023';
  end if;
  if in_category is null
     or not exists (select 1 from unnest(enum_range(null::store_category)) e
                    where e::text = in_category) then
    raise exception 'invalid category' using errcode = '22023';
  end if;
  if in_halal_scope is null
     or not exists (select 1 from unnest(enum_range(null::halal_scope)) e
                    where e::text = in_halal_scope) then
    raise exception 'invalid halal_scope' using errcode = '22023';
  end if;

  -- spatial dedupe: a non-rejected store with the same (case-insensitive) name
  -- within 150 m is treated as the same place.
  select s.id into v_dup
  from public.stores s
  where s.status in ('approved','pending')
    and lower(btrim(s.name)) = lower(btrim(in_name))
    and st_dwithin(s.location, v_point, 150)
  limit 1;
  if v_dup is not null then
    raise exception 'duplicate store nearby: %', v_dup using errcode = '23505';
  end if;

  insert into public.stores
    (name, category, halal_scope, address, city, state, zip, location,
     certifications, source, submitted_by, status)
  values
    (btrim(in_name), in_category::store_category, in_halal_scope::halal_scope,
     coalesce(btrim(in_address), ''), coalesce(btrim(in_city), ''),
     coalesce(btrim(in_state), ''), coalesce(btrim(in_zip), ''),
     v_point, '{}', 'community', v_uid, 'pending')
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.submit_store(
  text, text, text, text, text, text, text, double precision, double precision
) to authenticated;

-- NOTE (approval): pending → approved is a MANUAL/admin action done with the
-- service-role key (or a SQL editor session), which bypasses RLS — same model as
-- review_requests verdicts:
--   update public.stores set status='approved' where id='<uuid>';
-- Approving a store is all it takes for it to appear on the public map.

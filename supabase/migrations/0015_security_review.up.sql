-- ============================================================================
-- 0015_security_review (UP) — findings from the Oct 22 security review.
--
--   1. Grants: Supabase's defaults give anon/authenticated TRUNCATE, TRIGGER and
--      REFERENCES on every public table. TRUNCATE ignores RLS. PostgREST can't
--      issue it today, but a grant that bypasses RLS shouldn't exist at all.
--      apple_tokens and review_agent_drafts are server-only, so the app roles
--      get nothing on them.
--   2. review_requests: photo_paths was trusted as sent. The agent signs every
--      path with the service key, so a user could name ANOTHER user's photos and
--      have them pulled into the research run. Paths must now sit in the
--      caller's own folder. Text fields and photo count are capped too.
--   3. stores: submit_store had no rate limit or length caps, so one account
--      could fill the moderation queue. 10 submissions a day, sane lengths.
--   4. delete_my_account deleted a user's votes but left confirm/dispute counts
--      on the stores they had voted on. It now recounts them.
--
-- Idempotent.
-- ============================================================================

-- 1) Grants -------------------------------------------------------------------
revoke truncate, trigger, references on
  public.review_requests, public.stores, public.store_votes,
  public.apple_tokens, public.review_agent_drafts
  from anon, authenticated;
revoke all on public.apple_tokens, public.review_agent_drafts from anon, authenticated;
-- anon never writes a review request (the insert policy is authenticated-only).
revoke insert, update, delete on public.review_requests from anon;

-- 2) review_requests insert guard (0014's trigger, plus input checks) ---------
create or replace function public.review_requests_rate_limit() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  p text;
begin
  new.created_at     := now();
  new.status         := 'pending';
  new.verdict        := null;
  new.verdict_reason := null;
  new.evidence       := null;
  new.reviewed_at    := null;

  if coalesce(array_length(new.photo_paths, 1), 0) not between 1 and 6 then
    raise exception 'Add between 1 and 6 photos.' using errcode = '22023';
  end if;
  foreach p in array new.photo_paths loop
    if split_part(p, '/', 1) <> new.user_id::text or p like '%..%' then
      raise exception 'invalid photo path' using errcode = '42501';
    end if;
  end loop;
  if length(new.product_name) > 200 or length(new.barcode) > 64 or length(new.notes) > 2000 then
    raise exception 'That text is too long.' using errcode = '22001';
  end if;

  if (select count(*) from public.review_requests
      where user_id = new.user_id and created_at > now() - interval '24 hours') >= 5 then
    raise exception 'You can send 5 review requests a day. Try again tomorrow.'
      using errcode = 'P0001';
  end if;
  return new;
end $$;

-- 3) stores: community submission limits --------------------------------------
create or replace function public.stores_submission_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.submitted_by is null then return new; end if;   -- seeds / service role
  if length(new.name) > 120 or length(new.address) > 200 or length(new.city) > 80
     or length(new.state) > 40 or length(new.zip) > 16 then
    raise exception 'That text is too long.' using errcode = '22001';
  end if;
  if (select count(*) from public.stores
      where submitted_by = new.submitted_by and created_at > now() - interval '24 hours') >= 10 then
    raise exception 'You can add 10 places a day. Try again tomorrow.' using errcode = 'P0001';
  end if;
  return new;
end $$;

drop trigger if exists stores_submission_guard on public.stores;
create trigger stores_submission_guard before insert on public.stores
  for each row execute function public.stores_submission_guard();

-- 4) delete_my_account: keep vote counts honest ---------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_stores uuid[];
begin
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;

  select array_agg(store_id) into v_stores from public.store_votes where user_id = v_uid;

  -- Fully personal rows → delete.
  delete from public.store_votes     where user_id = v_uid;
  delete from public.review_requests where user_id = v_uid;

  -- The stores this user voted on lose that vote from their tallies.
  update public.stores s set
    confirm_count = (select count(*) from public.store_votes v where v.store_id = s.id and v.vote = 'confirm'),
    dispute_count = (select count(*) from public.store_votes v where v.store_id = s.id and v.vote = 'dispute')
  where s.id = any(coalesce(v_stores, '{}'));

  -- Pending submissions (never made public) → delete.
  delete from public.stores where submitted_by = v_uid and status <> 'approved';
  -- Approved community stores → keep the listing, drop the personal link.
  update public.stores set submitted_by = null
    where submitted_by = v_uid and status = 'approved';
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

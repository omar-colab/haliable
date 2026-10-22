-- 0015_security_review (DOWN) — back to 0014's guard and 0006's delete RPC.
-- The revoked grants are not restored: they were never needed.
drop trigger if exists stores_submission_guard on public.stores;
drop function if exists public.stores_submission_guard();

create or replace function public.review_requests_rate_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.created_at     := now();
  new.status         := 'pending';
  new.verdict        := null;
  new.verdict_reason := null;
  new.evidence       := null;
  new.reviewed_at    := null;
  if (select count(*) from public.review_requests
      where user_id = new.user_id and created_at > now() - interval '24 hours') >= 5 then
    raise exception 'You can send 5 review requests a day. Try again tomorrow.'
      using errcode = 'P0001';
  end if;
  return new;
end $$;

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;
  delete from public.store_votes     where user_id = v_uid;
  delete from public.review_requests where user_id = v_uid;
  delete from public.stores where submitted_by = v_uid and status <> 'approved';
  update public.stores set submitted_by = null
    where submitted_by = v_uid and status = 'approved';
end;
$$;

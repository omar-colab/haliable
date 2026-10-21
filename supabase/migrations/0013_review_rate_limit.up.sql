-- ============================================================================
-- 0013_review_rate_limit (UP) — every review request costs a paid AI call and
-- an email, so cap it where the client can't skip it: 5 per user per 24h.
-- ============================================================================
create or replace function public.review_requests_rate_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.review_requests
      where user_id = new.user_id and created_at > now() - interval '24 hours') >= 5 then
    raise exception 'You can send 5 review requests a day. Try again tomorrow.'
      using errcode = 'P0001';
  end if;
  return new;
end $$;

drop trigger if exists review_requests_rate_limit on public.review_requests;
create trigger review_requests_rate_limit before insert on public.review_requests
  for each row execute function public.review_requests_rate_limit();

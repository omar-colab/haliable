-- 0014_review_insert_guard (DOWN) — back to 0013's rate-limit-only trigger.
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

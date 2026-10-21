-- ============================================================================
-- 0014_review_insert_guard (UP) — a client INSERT sets only what the user says
-- (product, barcode, notes, photos). Server-owned columns are forced here:
--   • created_at = now(): a back-dated row slipped past 0013's 24h count
--   • status/verdict/reason/evidence/reviewed_at: no self-"completed" verdicts
-- Same trigger as 0013, so the rate limit counts the forced timestamp.
-- ============================================================================
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

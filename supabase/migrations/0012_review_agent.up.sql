-- ============================================================================
-- 0012_review_agent (UP) — hand every new review request to the cloud agent.
--
-- On INSERT, pg_net POSTs {id} to the `review-agent` Edge Function. The agent
-- researches, emails Omar a draft with Approve / Reject links, and writes the
-- draft to `review_agent_drafts` only. Users never see it: the app reads status /
-- verdict / verdict_reason, which only `review-decide` (Omar's click) sets.
-- ============================================================================

create extension if not exists pg_net with schema extensions;

-- Agent state lives in its own table: RLS on, NO policies, so only the
-- service role (the Edge Functions) can read it. The decision token is what
-- guards the approve link, so it must never be readable by the app.
create table if not exists public.review_agent_drafts (
  request_id     uuid primary key references public.review_requests(id) on delete cascade,
  status         text not null default 'researching'
                   check (status in ('researching','drafted','failed','approved','rejected')),
  draft          jsonb,
  decision_token uuid not null default gen_random_uuid(),
  updated_at     timestamptz not null default now()
);
alter table public.review_agent_drafts enable row level security;
revoke all on public.review_agent_drafts from anon, authenticated;

create or replace function public.notify_review_agent() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform net.http_post(
    url := 'https://abumevloleevhoqxfnoe.supabase.co/functions/v1/review-agent',
    body := jsonb_build_object('id', new.id),
    headers := '{"Content-Type":"application/json"}'::jsonb,
    timeout_milliseconds := 5000);   -- fire-and-forget; the function runs on
  return new;                         -- its own clock after acknowledging
end $$;

drop trigger if exists review_requests_agent on public.review_requests;
create trigger review_requests_agent after insert on public.review_requests
  for each row execute function public.notify_review_agent();

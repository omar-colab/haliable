-- ============================================================================
-- 0018_agents_digest (UP) — the agents work on their own; Omar approves by email.
--
-- 1. ingredient_research gets a decision: the daily digest emails every new
--    finding with ✅/❌ links (review-decide). Approve → `reviewed`, the app says
--    "checked by Haliable". Reject → its sources are cleared, users stop seeing
--    them. Neither changes a grade (that stays the citation pipeline's job).
-- 2. place_research: the `place-scout` agent checks a place's halal certificate
--    AND its menu. It runs on every community submission (trigger below) and on
--    Apple Maps restaurants the app passes it. Approve → the place goes on the
--    public map (approved), reject → it doesn't. Service role only.
-- 3. pg_cron calls `daily-digest` once a day. The digest only sends rows not yet
--    emailed, so an extra call can't spam.
-- ============================================================================

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

alter table public.ingredient_research
  add column if not exists decision       text check (decision in ('approved','rejected')),
  add column if not exists decision_token uuid not null default gen_random_uuid(),
  add column if not exists emailed_at     timestamptz;
-- The token guards the approve link; the app's column grants (0017) never include it.

create table if not exists public.place_research (
  id             uuid primary key default gen_random_uuid(),
  -- lower(name) + coords to ~100 m: one lookup per place for everyone.
  place_key      text not null unique check (char_length(place_key) <= 200),
  store_id       uuid references public.stores(id) on delete cascade,
  name           text not null check (char_length(name) between 2 and 120),
  address        text not null default '' check (char_length(address) <= 200),
  city           text not null default '' check (char_length(city) <= 80),
  state          text not null default '' check (char_length(state) <= 40),
  category       store_category not null default 'other',
  lat            double precision not null check (lat between -90 and 90),
  lng            double precision not null check (lng between -180 and 180),
  status         text not null default 'researching'
                   check (status in ('researching','done','failed')),
  -- halal_scope values, or not_halal / unknown
  verdict        text,
  certifier      text,
  menu           jsonb not null default '[]'::jsonb,
  summary        text,
  sources        jsonb not null default '[]'::jsonb,
  decision       text check (decision in ('approved','rejected')),
  decision_token uuid not null default gen_random_uuid(),
  emailed_at     timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists place_research_created_at on public.place_research (created_at);
alter table public.place_research enable row level security;
revoke all on public.place_research from anon, authenticated;

-- Every community submission is researched before it reaches Omar.
create or replace function public.notify_place_scout() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
begin
  if new.status = 'pending' then
    perform net.http_post(
      url := 'https://abumevloleevhoqxfnoe.supabase.co/functions/v1/place-scout',
      body := jsonb_build_object('store_id', new.id,
                                 'lat', st_y(new.location::geometry), 'lng', st_x(new.location::geometry)),
      headers := '{"Content-Type":"application/json"}'::jsonb,
      timeout_milliseconds := 5000);
  end if;
  return new;
end $$;
revoke execute on function public.notify_place_scout() from public, anon, authenticated;

drop trigger if exists stores_place_scout on public.stores;
create trigger stores_place_scout after insert on public.stores
  for each row execute function public.notify_place_scout();

-- 13:00 UTC = 8–9 am US Eastern.
select cron.unschedule('haliable-daily-digest')
  where exists (select 1 from cron.job where jobname = 'haliable-daily-digest');
select cron.schedule('haliable-daily-digest', '0 13 * * *', $$
  select net.http_post(
    url := 'https://abumevloleevhoqxfnoe.supabase.co/functions/v1/daily-digest',
    body := '{}'::jsonb,
    headers := '{"Content-Type":"application/json"}'::jsonb,
    timeout_milliseconds := 5000);
$$);

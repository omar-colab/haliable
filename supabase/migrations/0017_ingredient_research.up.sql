-- ============================================================================
-- 0017_ingredient_research (UP) — the in-app research bot's shared notebook.
--
-- When a scan flags an ingredient that has no citation yet, the app asks the
-- `source-scout` Edge Function to look for published sources. Each ingredient
-- is researched ONCE for everyone (the term is the key), so the cost follows
-- the number of distinct ingredients, not the number of scans.
--
-- Only quotes the function found word-for-word on their page are stored. A row
-- never changes a grade: the app shows it as "found automatically, not yet
-- reviewed", and only Omar's approval (citation pipeline) can turn it into a
-- citation.
-- ============================================================================

create table if not exists public.ingredient_research (
  term         text primary key
                 check (char_length(term) between 2 and 60 and term ~ '^[a-z0-9][a-z0-9 -]*$'),
  status       text not null default 'researching'
                 check (status in ('researching','done','failed')),
  summary      text,
  sources      jsonb not null default '[]'::jsonb,
  reviewed     boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists ingredient_research_created_at on public.ingredient_research (created_at);

-- Anyone may READ results (they are about ingredients, not people; nothing about
-- who asked is stored), except the model's own summary, which is Omar's only.
-- Writes are the service role's only.
alter table public.ingredient_research enable row level security;
revoke all on public.ingredient_research from anon, authenticated;
grant select (term, status, sources, reviewed, updated_at)
  on public.ingredient_research to anon, authenticated;
drop policy if exists ingredient_research_read on public.ingredient_research;
create policy ingredient_research_read on public.ingredient_research
  for select to anon, authenticated using (true);

-- ============================================================================
-- 0018_agents_digest (DOWN)
-- ============================================================================
select cron.unschedule('haliable-daily-digest')
  where exists (select 1 from cron.job where jobname = 'haliable-daily-digest');
drop trigger if exists stores_place_scout on public.stores;
drop function if exists public.notify_place_scout();
drop table if exists public.place_research;
alter table public.ingredient_research
  drop column if exists emailed_at,
  drop column if exists decision_token,
  drop column if exists decision;

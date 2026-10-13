-- ============================================================================
-- Haliable — Supabase setup for the PHOTO MANUAL-REVIEW feature
-- Run this in the Supabase dashboard → SQL Editor (one project, free tier).
-- (The Store Atlas backend is separate and deferred — see the dossier Appendix A.)
-- ============================================================================

create extension if not exists "pgcrypto";

-- 1) The review queue table -------------------------------------------------
create table if not exists public.review_requests (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  product_name  text,
  barcode       text,
  notes         text,
  photo_paths   text[] not null default '{}',
  status        text not null default 'pending'
                  check (status in ('pending','in_review','completed')),
  verdict       text check (verdict in ('halal','haram','doubtful')),
  verdict_reason text,
  created_at    timestamptz not null default now(),
  reviewed_at   timestamptz
);

create index if not exists review_requests_user_idx on public.review_requests(user_id);

-- 2) Row-Level Security: users only see / create their OWN requests ----------
alter table public.review_requests enable row level security;

drop policy if exists "insert own review" on public.review_requests;
create policy "insert own review" on public.review_requests
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "read own reviews" on public.review_requests;
create policy "read own reviews" on public.review_requests
  for select to authenticated using (auth.uid() = user_id);

-- You (the reviewer) set the verdict from the dashboard or a service-role
-- script, which bypasses RLS. To do it as an admin user instead, add an
-- UPDATE policy keyed to your admin uid.

-- 3) Private storage bucket for the photos ----------------------------------
insert into storage.buckets (id, name, public)
values ('review-photos', 'review-photos', false)
on conflict (id) do nothing;

-- Users may upload/read/delete only inside their own folder: {uid}/{requestId}/{n}.jpg
drop policy if exists "upload own review photos" on storage.objects;
create policy "upload own review photos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'review-photos'
              and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "read own review photos" on storage.objects;
create policy "read own review photos" on storage.objects
  for select to authenticated
  using (bucket_id = 'review-photos'
         and (storage.foldername(name))[1] = auth.uid()::text);

-- Delete is needed by account deletion: the app removes {uid}/… itself
-- (AccountService), and without this policy Storage silently deletes NOTHING —
-- no error — so a "deleted" account's photos would survive on the server.
drop policy if exists "delete own review photos" on storage.objects;
create policy "delete own review photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'review-photos'
         and (storage.foldername(name))[1] = auth.uid()::text);

-- ----------------------------------------------------------------------------
-- To RETURN a verdict to a user (until you build an admin screen), run e.g.:
--
--   update public.review_requests
--      set status='completed',
--          verdict='doubtful',
--          verdict_reason='Gelatin source unconfirmed; treat as Questionable.',
--          reviewed_at=now()
--    where id='<request-uuid>';
--
-- The app shows it on next pull-to-refresh in My Reviews.
-- ============================================================================

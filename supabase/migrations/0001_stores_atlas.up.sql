-- ============================================================================
-- 0001_stores_atlas (UP) — Store Atlas backend: stores table + spatial read.
-- Reversible: see 0001_stores_atlas.down.sql.
-- The community-submit write policies are deferred to a Phase 2 migration.
-- ============================================================================

create extension if not exists pgcrypto;
create extension if not exists postgis;

-- 1) Enums -------------------------------------------------------------------
-- Guarded so re-running the migration doesn't error on the type already existing.
do $$ begin
  create type store_source as enum ('seed','community','verified');
exception when duplicate_object then null; end $$;

do $$ begin
  create type store_status as enum ('pending','approved','rejected');
exception when duplicate_object then null; end $$;

do $$ begin
  create type store_category as enum
    ('grocery','butcher','restaurant','bakery','cafe','supermarket','other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type halal_scope as enum
    ('fully_halal','halal_meat_only','halal_options','unverified');
exception when duplicate_object then null; end $$;

-- 2) Table -------------------------------------------------------------------
create table if not exists public.stores (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  category       store_category not null default 'other',
  halal_scope    halal_scope not null default 'unverified',
  address        text not null default '',
  city           text not null default '',
  state          text not null default '',
  zip            text not null default '',
  location       geography(Point,4326) not null,
  certifications text[] not null default '{}',
  source         store_source not null default 'community',
  submitted_by   uuid references auth.users(id) on delete set null,
  status         store_status not null default 'pending',
  confirm_count  int not null default 0,
  dispute_count  int not null default 0,
  created_at     timestamptz not null default now()
);

-- Spatial index powers the radius query; status index keeps the approved filter cheap.
create index if not exists stores_location_gix on public.stores using gist (location);
create index if not exists stores_status_idx   on public.stores (status);

-- 3) Row-Level Security ------------------------------------------------------
-- Phase 1 is read-only to the public: anyone may SELECT an APPROVED store, and
-- nothing else. Pending/rejected rows are invisible. (Insert + own-pending-read
-- policies come with Phase 2.) Seed + admin writes use the service-role key,
-- which bypasses RLS.
alter table public.stores enable row level security;

grant select on public.stores to anon, authenticated;

drop policy if exists "read approved stores" on public.stores;
create policy "read approved stores" on public.stores
  for select
  using (status = 'approved');

-- 4) Spatial read RPC --------------------------------------------------------
-- The app's single read entry point. Returns APPROVED stores within radius_km of
-- (lat,lng), nearest first, with a computed distance in metres. Shape matches the
-- client `Store` Codable exactly so it decodes with no translation layer.
create or replace function public.stores_nearby(
  in_lat       double precision,
  in_lng       double precision,
  in_radius_km double precision default 5,
  in_category  text default null
)
returns table (
  id             uuid,
  name           text,
  category       text,
  halal_scope    text,
  address        text,
  city           text,
  state          text,
  zip            text,
  lat            double precision,
  lng            double precision,
  certifications text[],
  status         text,
  confirm_count  int,
  dispute_count  int,
  distance_m     double precision,
  created_at     timestamptz
)
language sql
stable
as $$
  select
    s.id,
    s.name,
    s.category::text,
    s.halal_scope::text,
    s.address, s.city, s.state, s.zip,
    st_y(s.location::geometry) as lat,
    st_x(s.location::geometry) as lng,
    s.certifications,
    s.status::text,
    s.confirm_count,
    s.dispute_count,
    st_distance(
      s.location,
      st_setsrid(st_makepoint(in_lng, in_lat), 4326)::geography
    ) as distance_m,
    s.created_at
  from public.stores s
  where s.status = 'approved'
    and st_dwithin(
      s.location,
      st_setsrid(st_makepoint(in_lng, in_lat), 4326)::geography,
      in_radius_km * 1000.0
    )
    and (in_category is null or s.category::text = in_category)
  order by distance_m asc;
$$;

grant execute on function public.stores_nearby(double precision, double precision, double precision, text)
  to anon, authenticated;

-- ============================================================================
-- 0008_security_hardening (UP) — from the Phase 2 security audit.
--
-- Caps review-photo uploads, and documents one issue that CANNOT be fixed from
-- SQL (see the note at the bottom — read it before assuming the audit is clean).
--
-- Idempotent.
-- ============================================================================

-- Cap review photo uploads. ImageCompressor resizes to 1600px and uploads JPEG,
-- so 5 MiB is generous. Without a cap an authenticated user could push
-- arbitrarily large files of any type into storage we pay for.
update storage.buckets
set file_size_limit    = 5242880,   -- 5 MiB
    allowed_mime_types = array['image/jpeg','image/png','image/heic','image/heif']
where id = 'review-photos';


-- ── KNOWN, UNFIXED: anon can write to public.spatial_ref_sys ────────────────
--
-- PostGIS installs spatial_ref_sys into `public`, and Supabase's default
-- privileges grant ALL on everything in `public` to anon + authenticated. The
-- table is owned by the postgis extension, so RLS cannot be enabled on it
-- without superuser — which means the grants ARE the entire boundary.
--
-- Verified empirically (2026-10-13), not assumed: an anonymous INSERT with the
-- publishable key is rejected with 23514, a CHECK CONSTRAINT violation on the
-- srid range — i.e. it passes the permission check and fails only on data
-- validation. A row with a valid srid would be accepted.
--
-- REVOKE does not work. The grants' grantor is `supabase_admin`; the SQL Editor
-- and the Management API both run as `postgres`, which cannot assume that role,
-- so a REVOKE here silently no-ops. Statements to that effect were removed from
-- this migration rather than left in looking effective.
--
-- Impact: not a data leak. The blast radius is corrupting or deleting SRID 4326,
-- which `stores.location geography(Point,4326)` depends on — that would break the
-- Store Atlas until the row was restored. Denial of service, not disclosure.
-- Anyone can do it, since the publishable key ships in the app by design.
--
-- The real fix is Supabase's own recommendation: install postgis into a separate
-- `extensions` schema instead of `public` (the default for projects created more
-- recently than this one). That means recreating the geography column and its
-- index, so it is NOT a thing to do days before a demo. Tracked in HANDOFF.md.
--
-- Mitigation meanwhile: `stores` is seeded and read-only to the public, so if
-- 4326 were ever vandalised, re-running 0001 + 0007 restores everything.

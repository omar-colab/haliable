-- ============================================================================
-- 0008_security_hardening (DOWN) — removes the review-photo upload caps.
-- Reverses only what 0008 actually changed.
-- ============================================================================

update storage.buckets
set file_size_limit    = null,
    allowed_mime_types = null
where id = 'review-photos';

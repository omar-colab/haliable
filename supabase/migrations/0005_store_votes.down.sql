-- ============================================================================
-- 0005_store_votes (DOWN) — reverse 0005_store_votes.up.sql.
-- Dropping the table also drops its policies + index. Existing confirm_count /
-- dispute_count values on stores are left as-is (harmless integers).
-- ============================================================================

drop function if exists public.vote_store(uuid, text);
drop table if exists public.store_votes;

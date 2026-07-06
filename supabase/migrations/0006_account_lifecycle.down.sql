-- ============================================================================
-- 0006_account_lifecycle (DOWN) — reverse 0006_account_lifecycle.up.sql.
-- ============================================================================

drop function if exists public.delete_my_account();
drop table if exists public.apple_tokens;

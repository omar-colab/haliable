-- ============================================================================
-- 0012_review_agent (DOWN)
-- ============================================================================
drop trigger if exists review_requests_agent on public.review_requests;
drop function if exists public.notify_review_agent();
drop table if exists public.review_agent_drafts;

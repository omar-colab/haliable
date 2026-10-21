-- 0013_review_rate_limit (DOWN)
drop trigger if exists review_requests_rate_limit on public.review_requests;
drop function if exists public.review_requests_rate_limit();

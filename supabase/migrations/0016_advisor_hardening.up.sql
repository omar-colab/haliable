-- ============================================================================
-- 0016_advisor_hardening (UP) — Supabase Security/Performance Advisor, Oct 22.
--
--   1. Trigger functions were EXECUTE-able by anon/authenticated through
--      /rest/v1/rpc. Triggers don't need the grant to fire, so nobody gets it.
--   2. submit_store / vote_store refuse anon inside the body already; revoke
--      the grant too so anon can't even reach them. delete_my_account stays
--      callable by signed-in users (that's its job).
--   3. stores_nearby had no pinned search_path.
--   4. RLS policies called auth.uid() per row; (select auth.uid()) runs once.
--   5. Indexes for the two foreign keys the advisor flagged.
--
-- Not changed: PostGIS in public (moving it rewrites the stores column types;
-- tracked in 0008) and its own st_estimatedextent / spatial_ref_sys, which
-- belong to the extension owner.
-- ============================================================================

revoke execute on function public.notify_review_agent()         from public, anon, authenticated;
revoke execute on function public.review_requests_rate_limit()  from public, anon, authenticated;
revoke execute on function public.stores_submission_guard()     from public, anon, authenticated;

revoke execute on function public.submit_store(text, text, text, text, text, text, text, double precision, double precision) from public, anon;
revoke execute on function public.vote_store(uuid, text) from public, anon;
revoke execute on function public.delete_my_account()    from public, anon;

alter function public.stores_nearby(double precision, double precision, double precision, text)
  set search_path = public, extensions;

alter policy "insert own review"    on public.review_requests with check ((select auth.uid()) = user_id);
alter policy "read own reviews"     on public.review_requests using ((select auth.uid()) = user_id);
alter policy "read own votes"       on public.store_votes     using (user_id = (select auth.uid()));
alter policy "read own submissions" on public.stores          using (submitted_by = (select auth.uid()));

create index if not exists store_votes_user_id_idx   on public.store_votes (user_id);
create index if not exists stores_submitted_by_idx   on public.stores (submitted_by);

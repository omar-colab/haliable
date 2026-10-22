-- 0016_advisor_hardening (DOWN) — restores the grants, search_path and policy forms.
grant execute on function public.notify_review_agent()        to anon, authenticated;
grant execute on function public.review_requests_rate_limit() to anon, authenticated;
grant execute on function public.stores_submission_guard()    to anon, authenticated;
grant execute on function public.submit_store(text, text, text, text, text, text, text, double precision, double precision) to anon;
grant execute on function public.vote_store(uuid, text) to anon;
grant execute on function public.delete_my_account()    to anon;

alter function public.stores_nearby(double precision, double precision, double precision, text) reset search_path;

alter policy "insert own review"    on public.review_requests with check (auth.uid() = user_id);
alter policy "read own reviews"     on public.review_requests using (auth.uid() = user_id);
alter policy "read own votes"       on public.store_votes     using (user_id = auth.uid());
alter policy "read own submissions" on public.stores          using (submitted_by = auth.uid());

drop index if exists public.store_votes_user_id_idx;
drop index if exists public.stores_submitted_by_idx;

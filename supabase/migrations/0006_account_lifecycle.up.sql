-- ============================================================================
-- 0006_account_lifecycle (UP) — App Store Guideline 5.1.1(v) account deletion.
--   • apple_tokens: server-side store of each user's Sign in with Apple refresh
--     token (written by the apple-store-token function, read by apple-revoke).
--     Service-role only — RLS denies all client access.
--   • delete_my_account(): the authenticated user erases their own data. Personal
--     rows are deleted; APPROVED community stores are anonymized (submitted_by →
--     null) so the public map survives without keeping a personal link.
-- Reversible: see 0006_account_lifecycle.down.sql.
-- ============================================================================

-- 1) Apple refresh-token store (for token revocation on deletion) -------------
create table if not exists public.apple_tokens (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  refresh_token text not null,
  updated_at    timestamptz not null default now()
);

-- RLS on, NO policies → only the service-role key (server functions) may touch it.
alter table public.apple_tokens enable row level security;

-- 2) The authenticated-user account-deletion RPC -----------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'auth required' using errcode = '28000';
  end if;

  -- Fully personal rows → delete.
  delete from public.store_votes     where user_id = v_uid;
  delete from public.review_requests where user_id = v_uid;

  -- Pending submissions (never made public) → delete.
  delete from public.stores where submitted_by = v_uid and status <> 'approved';
  -- Approved community stores → keep the listing, drop the personal link.
  update public.stores set submitted_by = null
    where submitted_by = v_uid and status = 'approved';
end;
$$;

grant execute on function public.delete_my_account() to authenticated;

-- DELETION ORDER (app → server): the app calls this RPC to erase its public rows
-- FIRST, then calls the apple-revoke function LAST. That function reads the stored
-- Apple refresh token, revokes it with Apple, and admin-deletes auth.users (which
-- cascades apple_tokens). Revoke runs last because deleting auth.users invalidates
-- the session this RPC needs. Review photos in the `review-photos` Storage bucket
-- (under {uid}/…) are removed by the app from its own folder during deletion;
-- Storage objects aren't reachable from SQL here.

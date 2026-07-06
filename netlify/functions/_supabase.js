// _supabase.js — minimal Supabase admin helpers over fetch (no external deps).
//
// Required env (NEVER commit):
//   SUPABASE_URL                — https://<ref>.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY   — service_role key (server-only; bypasses RLS)

const URL = process.env.SUPABASE_URL;
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY;

function svcHeaders(extra = {}) {
  return { apikey: SERVICE, Authorization: `Bearer ${SERVICE}`, ...extra };
}

/// Identify the caller from their Supabase access token. Returns the user or null.
async function getUser(accessToken) {
  const r = await fetch(`${URL}/auth/v1/user`, {
    headers: { apikey: SERVICE, Authorization: `Bearer ${accessToken}` },
  });
  return r.ok ? r.json() : null;
}

async function upsertAppleToken(userId, refreshToken) {
  await fetch(`${URL}/rest/v1/apple_tokens`, {
    method: "POST",
    headers: svcHeaders({ "Content-Type": "application/json", Prefer: "resolution=merge-duplicates" }),
    body: JSON.stringify({
      user_id: userId,
      refresh_token: refreshToken,
      updated_at: new Date().toISOString(),
    }),
  });
}

async function getAppleToken(userId) {
  const r = await fetch(
    `${URL}/rest/v1/apple_tokens?user_id=eq.${userId}&select=refresh_token`,
    { headers: svcHeaders() }
  );
  const rows = await r.json().catch(() => []);
  return Array.isArray(rows) && rows[0] ? rows[0].refresh_token : null;
}

/// Admin-delete the auth user. Cascades apple_tokens (FK on delete cascade).
async function deleteAuthUser(userId) {
  await fetch(`${URL}/auth/v1/admin/users/${userId}`, {
    method: "DELETE",
    headers: svcHeaders(),
  });
}

module.exports = { getUser, upsertAppleToken, getAppleToken, deleteAuthUser };

// _supabase.js — minimal Supabase admin helpers over fetch (no external deps).
//
// Required env (NEVER commit):
//   SUPABASE_URL          — https://<ref>.supabase.co
//   SUPABASE_SECRET_KEY   — sb_secret_… key (server-only; bypasses RLS)
//
// Falls back to SUPABASE_SERVICE_ROLE_KEY so a half-migrated environment still
// works. The legacy service_role key is retired by the end of 2026 — once the
// new key is set in Netlify, drop the old variable.

const URL = process.env.SUPABASE_URL;
const SERVICE = process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;

// The new sb_secret_/sb_publishable_ keys are NOT JWTs. Supabase's migration guide
// is explicit: "Send publishable and secret keys on the `apikey` header only. If you
// also pass the key on the `Authorization: Bearer` header … the platform tries to
// parse it as a JWT and rejects the request with `Invalid JWT`." The legacy
// service_role key was a JWT, which is why Bearer used to work here.
function svcHeaders(extra = {}) {
  return { apikey: SERVICE, ...extra };
}

/// Identify the caller from their Supabase access token. Returns the user or null.
async function getUser(accessToken) {
  // Note the asymmetry, and leave it alone: `apikey` authenticates the *project*
  // (secret key, no Bearer), while `Authorization` carries the *user's* access
  // token — which really is a JWT and must stay on Bearer for this to resolve a user.
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

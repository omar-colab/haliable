// apple-store-token.js — called by the app right after Sign in with Apple.
// Exchanges the one-time authorization code for an Apple refresh token and stores
// it, so the account-deletion flow can later revoke it (Apple TN3194).
//
// POST  body: { "code": "<apple authorization code>" }
//       header: Authorization: Bearer <supabase access token>

const { clientSecret } = require("./_apple");
const { getUser, upsertAppleToken } = require("./_supabase");

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") return { statusCode: 405, body: "Method Not Allowed" };

  const auth = event.headers.authorization || event.headers.Authorization || "";
  const accessToken = auth.replace(/^Bearer\s+/i, "");
  if (!accessToken) return { statusCode: 401, body: "Missing Authorization" };

  let code;
  try { code = JSON.parse(event.body || "{}").code; }
  catch { return { statusCode: 400, body: "Bad JSON" }; }
  if (!code) return { statusCode: 400, body: "Missing code" };

  // Identify the caller from their Supabase session.
  const user = await getUser(accessToken);
  if (!user || !user.id) return { statusCode: 401, body: "Invalid session" };

  // Exchange the authorization code for tokens.
  const body = new URLSearchParams({
    client_id: process.env.APPLE_CLIENT_ID,
    client_secret: clientSecret(),
    grant_type: "authorization_code",
    code,
  });
  const r = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const tok = await r.json().catch(() => ({}));
  if (!tok.refresh_token) return { statusCode: 502, body: "No refresh_token from Apple" };

  await upsertAppleToken(user.id, tok.refresh_token);
  return { statusCode: 204 };
};

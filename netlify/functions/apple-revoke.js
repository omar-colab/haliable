// apple-revoke.js — part of the account-deletion flow.
// Revokes the user's Apple refresh token (Apple TN3194). The app calls this
// after delete_my_account() and BEFORE the Supabase `delete-account` Edge
// Function, which removes photos and the auth user — the session must still be
// valid here for getUser() to resolve it.
//
// POST  header: Authorization: Bearer <supabase access token>

const { clientSecret } = require("./_apple");
const { getUser, getAppleToken } = require("./_supabase");

exports.handler = async (event) => {
  try { return await revoke(event); }
  // Never hand a stack trace (or an env var name) to the caller.
  catch (e) { console.error(e); return { statusCode: 500, body: "Revoke failed" }; }
};

async function revoke(event) {
  if (event.httpMethod !== "POST") return { statusCode: 405, body: "Method Not Allowed" };

  const auth = event.headers.authorization || event.headers.Authorization || "";
  const accessToken = auth.replace(/^Bearer\s+/i, "");
  if (!accessToken) return { statusCode: 401, body: "Missing Authorization" };

  const user = await getUser(accessToken);
  if (!user || !user.id) return { statusCode: 401, body: "Invalid session" };

  // 1. Revoke the Apple refresh token if we captured one at sign-in.
  const refreshToken = await getAppleToken(user.id);
  if (refreshToken) {
    const body = new URLSearchParams({
      client_id: process.env.APPLE_CLIENT_ID,
      client_secret: clientSecret(),
      token: refreshToken,
      token_type_hint: "refresh_token",
    });
    await fetch("https://appleid.apple.com/auth/revoke", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
    });
  }

  return { statusCode: 204 };
}

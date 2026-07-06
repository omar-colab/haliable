// apple-revoke.js — called LAST in the account-deletion flow.
// Revokes the user's Apple refresh token (Apple TN3194) and admin-deletes the
// Supabase auth user (which cascades apple_tokens). The app has already deleted
// its public rows + Storage photos before calling this.
//
// POST  header: Authorization: Bearer <supabase access token>

const { clientSecret } = require("./_apple");
const { getUser, getAppleToken, deleteAuthUser } = require("./_supabase");

exports.handler = async (event) => {
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

  // 2. Remove the account itself (cascades apple_tokens via FK).
  await deleteAuthUser(user.id);
  return { statusCode: 204 };
};

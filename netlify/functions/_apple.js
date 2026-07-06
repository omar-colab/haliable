// _apple.js — Sign in with Apple client-secret signer (no external deps).
//
// Builds the ES256 client-secret JWT Apple requires for /auth/token and
// /auth/revoke, signed with your AuthKey .p8. Uses Node's built-in crypto with
// dsaEncoding 'ieee-p1363' so the signature is in JOSE (raw R||S) form, not DER.
//
// Required env (set in Netlify → Site settings → Environment variables; NEVER
// commit these):
//   APPLE_TEAM_ID       — 10-char Team ID
//   APPLE_KEY_ID        — 10-char Key ID of the AuthKey
//   APPLE_CLIENT_ID     — the Services ID (or app Bundle ID) used for SIWA
//   APPLE_PRIVATE_KEY   — contents of AuthKey_XXXX.p8 (PEM; newlines as \n)

const crypto = require("crypto");

function b64url(input) {
  return Buffer.from(input)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function clientSecret() {
  const { APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_CLIENT_ID, APPLE_PRIVATE_KEY } = process.env;
  if (!APPLE_TEAM_ID || !APPLE_KEY_ID || !APPLE_CLIENT_ID || !APPLE_PRIVATE_KEY) {
    throw new Error("Missing Apple SIWA env vars");
  }
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: APPLE_KEY_ID };
  const payload = {
    iss: APPLE_TEAM_ID,
    iat: now,
    exp: now + 300, // Apple max 6 months; 5 min is plenty for a one-shot call.
    aud: "https://appleid.apple.com",
    sub: APPLE_CLIENT_ID,
  };
  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const key = APPLE_PRIVATE_KEY.replace(/\\n/g, "\n");
  const signature = crypto.sign("sha256", Buffer.from(signingInput), {
    key,
    dsaEncoding: "ieee-p1363",
  });
  return `${signingInput}.${b64url(signature)}`;
}

module.exports = { clientSecret, b64url };

// ─────────────────────────────────────────────────────────────
//  Haliable waitlist → MailerLite  (Netlify serverless function)
// ─────────────────────────────────────────────────────────────
//  The browser POSTs { email } here. This code runs on Netlify's
//  servers — NOT in the user's browser — so the secret API token is
//  never exposed. Values come from Netlify env vars
//  (Site settings → Environment variables), never from this file:
//
//    MAILERLITE_API_KEY    (required)  your MailerLite API token
//    MAILERLITE_GROUP_ID   (optional)  put signups into a specific group
//
//  Uses MailerLite's current API (connect.mailerlite.com). It upserts,
//  so re-subscribing an existing email is a normal success, not an error.
//  Dependency-free: uses Node 18+'s built-in fetch (Netlify default).
// ─────────────────────────────────────────────────────────────

exports.handler = async (event) => {
  // Only accept POST.
  if (event.httpMethod !== 'POST') {
    return json(405, { error: 'Method not allowed' });
  }

  // Parse + validate the email.
  let email, company;
  try {
    ({ email, company } = JSON.parse(event.body || '{}'));
  } catch {
    return json(400, { error: 'Invalid request.' });
  }
  // Honeypot: the "company" field is invisible to people, so only bots fill it.
  // Answer like a success so the bot learns nothing, and subscribe no one.
  if (company) return json(200, { ok: true });
  email = (email || '').trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return json(400, { error: 'Please enter a valid email address.' });
  }

  // Pull secrets from the environment.
  const TOKEN = process.env.MAILERLITE_API_KEY;
  const GROUP = process.env.MAILERLITE_GROUP_ID; // optional
  if (!TOKEN) {
    return json(500, { error: 'The waitlist isn’t configured yet. Please try again later.' });
  }

  const payload = { email };
  if (GROUP) payload.groups = [GROUP];

  try {
    const res = await fetch('https://connect.mailerlite.com/api/subscribers', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        Authorization: `Bearer ${TOKEN}`,
      },
      body: JSON.stringify(payload),
    });

    // 200 = existing subscriber updated, 201 = newly created. Both are success.
    if (res.ok) return json(200, { ok: true });

    const data = await res.json().catch(() => ({}));
    console.error('MailerLite error:', res.status, data.message || data);
    return json(400, { error: 'We couldn’t add you just now. Please try again.' });
  } catch (err) {
    console.error('Network error reaching MailerLite:', err);
    return json(502, { error: 'Network error. Please try again.' });
  }
};

function json(statusCode, body) {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  };
}

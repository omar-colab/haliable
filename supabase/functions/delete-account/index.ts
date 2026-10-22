// delete-account — the last step of in-app account deletion (App Store 5.1.1(v)).
//
// The app has already run delete_my_account() (rows) and asked Netlify's
// apple-revoke to revoke the Sign in with Apple token. This removes what only a
// server key can: every review photo in the user's folder, then the auth user
// itself (which cascades anything left). Lives here, not on Netlify, because
// this project's secret key is already set for the Edge Functions.
//
// POST  header: Authorization: Bearer <the user's Supabase access token>

import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const db = createClient("https://abumevloleevhoqxfnoe.supabase.co", Deno.env.get("HALIABLE_SECRET_KEY")!, { auth: { persistSession: false } });
const say = (status: number, body = "") => new Response(body || null, { status });

Deno.serve(async (r) => {
  if (r.method !== "POST") return say(405, "POST only");
  const jwt = (r.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data } = jwt ? await db.auth.getUser(jwt) : { data: { user: null } };
  const uid = data.user?.id;
  if (!uid) return say(401, "Invalid session");

  // review-photos/{uid}/{request}/{n}.jpg
  const bucket = db.storage.from("review-photos");
  const { data: folders, error: listErr } = await bucket.list(uid, { limit: 1000 });
  if (listErr) return say(500, "Couldn't list photos");
  const paths = (await Promise.all((folders ?? []).map(async (f) => {
    const { data: files } = await bucket.list(`${uid}/${f.name}`, { limit: 100 });
    return (files ?? []).map((x) => `${uid}/${f.name}/${x.name}`);
  }))).flat();
  if (paths.length) {
    const { error } = await bucket.remove(paths);
    if (error) return say(500, "Couldn't delete photos");
  }

  const { error } = await db.auth.admin.deleteUser(uid);
  if (error) return say(500, "Couldn't delete the account");
  return say(204);
});

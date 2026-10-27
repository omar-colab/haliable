// daily-digest — one email a day (pg_cron, 0018) with everything the agents
// found that needs Omar: ingredient sources (source-scout) and places
// (place-scout). Each item has ✅/❌ links handled by review-decide.
//
// Only rows not yet emailed are sent, then marked, so an extra call (anyone
// can hit the URL) sends nothing new instead of spamming. No email when empty.
//
// Secrets: HALIABLE_SECRET_KEY, RESEND_API_KEY, OWNER_EMAIL.

import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import { button, email, esc } from "../_shared/email.ts";
import { SCOPES } from "../_shared/place.ts";

const BASE = "https://abumevloleevhoqxfnoe.supabase.co";
const db = createClient(BASE, Deno.env.get("HALIABLE_SECRET_KEY")!, { auth: { persistSession: false } });
const MAX = 25;   // per kind per email; the rest wait for tomorrow

type Src = { name: string; url: string; tier: number; quote: string };
const link = (k: string, id: string, t: string, d: string) =>
  `${BASE}/functions/v1/review-decide?k=${k}&id=${encodeURIComponent(id)}&t=${t}&d=${d}`;
const buttons = (k: string, id: string, t: string, ok: string) =>
  `<p>${button(link(k, id, t, "approve"), ok, "#1f8a4c")} &nbsp; ${button(link(k, id, t, "reject"), "❌ Reject", "#b3261e")}</p>`;
const sources = (ss: Src[]) => ss.length
  ? `<ul>${ss.map((s) => `<li>Tier ${s.tier} · <a href="${esc(s.url)}">${esc(s.name)}</a><br><i>“${esc(s.quote)}”</i></li>`).join("")}</ul>`
  : "<p>No source with a verified quote.</p>";

Deno.serve(async () => {
  const [{ data: terms }, { data: places }] = await Promise.all([
    db.from("ingredient_research").select("term, summary, sources, decision_token")
      .eq("status", "done").is("emailed_at", null).is("decision", null).neq("sources", "[]").limit(MAX),
    db.from("place_research").select("*")
      .eq("status", "done").is("emailed_at", null).is("decision", null).limit(MAX * 2),
  ]);
  // A place is worth Omar's time if someone submitted it or the agent found it listable.
  const listable = (places ?? []).filter((p) => p.store_id || SCOPES.includes(p.verdict)).slice(0, MAX);
  // Unlisted Apple Maps finds (not halal / unknown) need nobody: close them quietly.
  const quiet = (places ?? []).filter((p) => !listable.includes(p)).map((p) => p.id);
  if (quiet.length) await db.from("place_research").update({ emailed_at: new Date().toISOString() }).in("id", quiet);
  if (!terms?.length && !listable.length) return new Response("nothing new");

  const termHtml = (terms ?? []).map((t) => `<hr><h3>Ingredient: ${esc(t.term)}</h3>
    <p>${esc(t.summary)}</p>${sources(t.sources)}
    ${buttons("ingredient", t.term, t.decision_token, "✅ Sources look right")}`).join("");

  const placeHtml = listable.map((p) => {
    const flagged = (p.menu as { item: string; status: string }[]).filter((m) => m.status !== "halal");
    const ok = SCOPES.includes(p.verdict);
    return `<hr><h3>${p.store_id ? "Submitted place" : "Found on Apple Maps"}: ${esc(p.name)}</h3>
      <p>${esc([p.address, p.city, p.state].filter(Boolean).join(", "))} · ${esc(p.category)}</p>
      <p><b>Agent's verdict: ${esc(String(p.verdict).replace(/_/g, " "))}</b>${p.certifier ? ` · certifier: ${esc(p.certifier)}` : ""}</p>
      <p>${esc(p.summary)}</p>
      ${flagged.length ? `<p>Menu items not confirmed halal: ${flagged.map((m) => `${esc(m.item)} (${esc(m.status)})`).join(", ")}</p>` : ""}
      ${sources((p.sources as (Src & { verified: boolean })[]).filter((s) => s.verified))}
      ${ok ? buttons("place", p.id, p.decision_token, "✅ Put on the map")
           : `<p>Not listable on what was found. ${button(link("place", p.id, p.decision_token, "reject"), "❌ Reject submission", "#b3261e")}</p>`}`;
  }).join("");

  const n = (terms?.length ?? 0) + listable.length;
  const sent = await email(`[Haliable] ${n} to approve — daily digest`,
    `<p>One tap each. Links work a minute after this email arrives. Nothing here changes a grade.</p>${termHtml}${placeHtml}`);
  if (!sent) return new Response("email failed", { status: 502 });   // stay unemailed → retried tomorrow

  const now = new Date().toISOString();
  if (terms?.length) await db.from("ingredient_research").update({ emailed_at: now }).in("term", terms.map((t) => t.term));
  if (listable.length) await db.from("place_research").update({ emailed_at: now }).in("id", listable.map((p) => p.id));
  return new Response(`sent ${n}`);
});

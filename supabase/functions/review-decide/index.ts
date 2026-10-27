// review-decide — Omar's one-tap Approve / Questionable / Reject links from the
// agent email. The tap itself acts and writes the answer into review_requests,
// which the app shows on its next refresh.
//
// approve → the agent's grade, with its verified sources.
// report  → "Questionable" plus every verified source, so the user reads them
//           and decides (the app reports what sources say; it doesn't rule).
// reject  → the request stays open for Omar to answer by hand.
//
// k=ingredient / k=place: the daily digest's ✅/❌ links (decideFinding).
//
// Replies are plain text: Supabase serves every function response as sandboxed
// text/plain, so an HTML confirm page showed as raw code and its button could
// never submit (Oct 22). Omar chose one tap over a confirm step; the decision
// is claimed atomically, so only the first tap (or link pre-fetch) ever counts.

import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import { tooSoon } from "../_shared/verdict.ts";
import { SCOPES } from "../_shared/place.ts";

const db = createClient("https://abumevloleevhoqxfnoe.supabase.co", Deno.env.get("HALIABLE_SECRET_KEY")!, { auth: { persistSession: false } });
const reply = (body: { message: string }, status = 200) =>
  new Response(body.message + "\n", { status, headers: { "Content-Type": "text/plain; charset=utf-8" } });

/** Ingredient sources and places from the daily digest. Approve/reject only;
 *  the decision is claimed atomically, so only the first tap counts. */
async function decideFinding(k: string, id: string, t: string, d: string, method: string): Promise<Response> {
  const table = k === "ingredient" ? "ingredient_research" : "place_research";
  const key = k === "ingredient" ? "term" : "id";
  const valid = k === "ingredient" ? /^[a-z0-9][a-z0-9 -]{1,59}$/.test(id) : /^[0-9a-f-]{36}$/.test(id);
  if (!valid || !/^[0-9a-f-]{36}$/.test(t) || !["approve", "reject"].includes(d)) return reply({ message: "Bad link." }, 400);
  if (method !== "GET") return reply({ message: "Use the link in the email." }, 405);

  const { data: row } = await db.from(table).select("*").eq(key, id).eq("decision_token", t).maybeSingle();
  if (!row) return reply({ message: "Link not valid." }, 404);
  if (row.decision) return reply({ message: `Already ${row.decision}.` });
  if (tooSoon(row.emailed_at)) {
    return reply({ message: "This link starts working a minute after the email arrives (so email scanners can't press it). Tap it again shortly." }, 425);
  }
  if (k === "place" && d === "approve" && !SCOPES.includes(row.verdict)) return reply({ message: "Nothing verified to list — reject it or add it by hand." }, 409);

  const decision = d === "approve" ? "approved" : "rejected";
  const { data: won } = await db.from(table).update({ decision, updated_at: new Date().toISOString() })
    .eq(key, id).is("decision", null).select(key);
  if (!won?.length) return reply({ message: "Already decided." });

  let error: unknown = null;
  if (k === "ingredient") {
    // Approve: the app says "checked by Haliable". Reject: users stop seeing the sources.
    ({ error } = await db.from(table).update(d === "approve" ? { reviewed: true } : { reviewed: true, sources: [] }).eq("term", id));
  } else if (row.store_id) {
    ({ error } = await db.from("stores").update(d === "approve"
      ? { status: "approved", halal_scope: row.verdict, certifications: row.certifier ? [row.certifier] : [] }
      : { status: "rejected" }).eq("id", row.store_id).eq("status", "pending"));
  } else if (d === "approve") {
    ({ error } = await db.from("stores").insert({
      name: row.name, category: row.category, halal_scope: row.verdict,
      address: row.address, city: row.city, state: row.state,
      location: `SRID=4326;POINT(${row.lng} ${row.lat})`,
      certifications: row.certifier ? [row.certifier] : [], source: "verified", status: "approved",
    }));
  }
  if (error) {
    await db.from(table).update({ decision: null }).eq(key, id);   // link works again once fixed
    console.error("decide", k, error);
    return reply({ message: "Couldn't save — try again in a minute." }, 500);
  }
  return reply({ message: k === "ingredient"
    ? (d === "approve" ? `Marked reviewed: ${id}. Grades are unchanged.` : `Rejected: ${id}. Users no longer see these sources.`)
    : (d === "approve" ? `${row.name} is on the map.` : `${row.name} rejected.`) });
}

Deno.serve(async (r) => {
  const u = new URL(r.url);
  const q = u.searchParams;
  const k = q.get("k");
  if (k === "ingredient" || k === "place") return decideFinding(k, q.get("id") ?? "", q.get("t") ?? "", q.get("d") ?? "", r.method);
  const id = q.get("id") ?? "", t = q.get("t") ?? "", d = q.get("d") ?? "";
  if (!/^[0-9a-f-]{36}$/.test(id) || !/^[0-9a-f-]{36}$/.test(t) || !["approve", "report", "reject"].includes(d)) {
    return reply({ message: "Bad link." }, 400);
  }

  const { data: row } = await db.from("review_agent_drafts").select("*").eq("request_id", id).eq("decision_token", t).maybeSingle();
  if (!row) return reply({ message: "Link not valid." }, 404);
  if (row.status === "approved" || row.status === "rejected") return reply({ message: `Already ${row.status}.` });

  const draft = row.draft ?? {};
  // Only machine-verified quotes ever reach a user; none verified → nothing to publish.
  const verified = (draft.sources ?? []).filter((s: { verified?: boolean }) => s.verified);

  if (r.method !== "GET") return reply({ message: "Use the link in the email." }, 405);

  // Mail link-scanners (Outlook Safe Links, Defender) open every link within
  // seconds of delivery; a person doesn't. Acting only after a minute keeps
  // one-tap for Omar without letting a scanner approve.
  if (tooSoon(row.updated_at)) {
    return reply({ message: "This link starts working a minute after the email arrives (so email scanners can't press it). Tap it again shortly." }, 425);
  }

  // Claim the decision atomically: of two taps (or approve + reject) racing,
  // only the one that flips the status acts.
  const open = ["researching", "drafted", "failed"];
  if (d === "reject") {
    const { data: won } = await db.from("review_agent_drafts").update({ status: "rejected", updated_at: new Date().toISOString() })
      .eq("request_id", id).in("status", open).select("request_id");
    if (!won?.length) return reply({ message: "Already decided." });
    await db.from("review_requests").update({ status: "in_review" }).eq("id", id);
    return reply({ message: "Rejected. The request is marked in review for you to answer." });
  }

  if (!draft.final) return reply({ message: "No draft to approve (the agent failed)." }, 409);
  if (!verified.length) return reply({ message: "No verified source — answer this one by hand." }, 409);
  const verdict = d === "report" ? "doubtful" : draft.final;
  const reason = d === "report"
    ? `${draft.summary}\n\nSources disagree or don't settle this product, so Haliable marks it Questionable. Read the sources below and decide for yourself.`
    : draft.summary;
  const { data: won } = await db.from("review_agent_drafts").update({ status: "approved", updated_at: new Date().toISOString() })
    .eq("request_id", id).in("status", open).select("request_id");
  if (!won?.length) return reply({ message: "Already decided." });
  const { error } = await db.from("review_requests").update({
    status: "completed", verdict, verdict_reason: reason,
    evidence: verified, reviewed_at: new Date().toISOString(),
  }).eq("id", id);
  if (error) {
    // Hand the decision back so the link works again after the fault is fixed.
    await db.from("review_agent_drafts").update({ status: row.status }).eq("request_id", id);
    console.error("publish", error);
    return reply({ message: "Couldn't publish — try again in a minute." }, 500);
  }
  return reply({ message: `Published: ${d === "report" ? "QUESTIONABLE + sources" : String(verdict).toUpperCase()}. The user sees it on their next refresh.` });
});

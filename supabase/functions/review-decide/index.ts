// review-decide — Omar's Approve / Questionable / Reject links from the agent email.
//
// approve → the agent's grade, with its verified sources.
// report  → "Questionable" plus every verified source, so the user reads them
//           and decides (the app reports what sources say; it doesn't rule).
//
// GET shows a confirm button; only the POST acts. Mail scanners pre-fetch
// links, and a GET that approved would publish verdicts nobody read.

import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const db = createClient("https://abumevloleevhoqxfnoe.supabase.co", Deno.env.get("HALIABLE_SECRET_KEY")!, { auth: { persistSession: false } });
const page = (body: string, status = 200) =>
  new Response(`<!doctype html><meta name="viewport" content="width=device-width"><body style="font:17px -apple-system,sans-serif;max-width:520px;margin:40px auto;padding:0 16px">${body}</body>`,
    { status, headers: { "Content-Type": "text/html; charset=utf-8" } });

Deno.serve(async (r) => {
  const u = new URL(r.url);
  const q = r.method === "POST" ? new URLSearchParams(await r.text()) : u.searchParams;
  const id = q.get("id") ?? "", t = q.get("t") ?? "", d = q.get("d") ?? "";
  if (!/^[0-9a-f-]{36}$/.test(id) || !/^[0-9a-f-]{36}$/.test(t) || !["approve", "report", "reject"].includes(d)) return page("Bad link.", 400);

  const { data: row } = await db.from("review_agent_drafts").select("*").eq("request_id", id).eq("decision_token", t).maybeSingle();
  if (!row) return page("Link not valid.", 404);
  if (row.status === "approved" || row.status === "rejected") return page(`Already ${row.status}.`);

  if (r.method !== "POST") {
    const ask = {
      approve: `Publish <b>${String(row.draft?.final ?? "").toUpperCase()}</b> to the user?`,
      report: "Send <b>QUESTIONABLE</b> with the verified sources, so the user can read them and decide?",
      reject: "Reject this draft? The request stays open for you to answer by hand.",
    }[d];
    const label = { approve: "✅ Approve", report: "🟡 Send as Questionable", reject: "❌ Reject" }[d];
    return page(`<p>${ask}</p>
      <form method="post"><input type="hidden" name="id" value="${id}"><input type="hidden" name="t" value="${t}"><input type="hidden" name="d" value="${d}">
      <button style="font-size:18px;padding:12px 22px">${label}</button></form>`);
  }

  // Claim the decision atomically: of two taps (or approve + reject) racing,
  // only the one that flips the status acts.
  const open = ["researching", "drafted", "failed"];
  if (d === "reject") {
    const { data: won } = await db.from("review_agent_drafts").update({ status: "rejected", updated_at: new Date().toISOString() })
      .eq("request_id", id).in("status", open).select("request_id");
    if (!won?.length) return page("Already decided.");
    await db.from("review_requests").update({ status: "in_review" }).eq("id", id);
    return page("Rejected. The request is marked in review for you to answer.");
  }

  const draft = row.draft ?? {};
  if (!draft.final) return page("No draft to approve (the agent failed).", 409);
  // Only machine-verified quotes ever reach a user; none verified → nothing to publish.
  const verified = (draft.sources ?? []).filter((s: { verified?: boolean }) => s.verified);
  if (!verified.length) return page("No verified source — answer this one by hand.", 409);
  const verdict = d === "report" ? "doubtful" : draft.final;
  const reason = d === "report"
    ? `${draft.summary}\n\nSources disagree or don't settle this product, so Haliable marks it Questionable. Read the sources below and decide for yourself.`
    : draft.summary;
  const { data: won } = await db.from("review_agent_drafts").update({ status: "approved", updated_at: new Date().toISOString() })
    .eq("request_id", id).in("status", open).select("request_id");
  if (!won?.length) return page("Already decided.");
  const { error } = await db.from("review_requests").update({
    status: "completed", verdict, verdict_reason: reason,
    evidence: verified, reviewed_at: new Date().toISOString(),
  }).eq("id", id);
  if (error) {
    // Hand the decision back so the link works again after the fault is fixed.
    await db.from("review_agent_drafts").update({ status: row.status }).eq("request_id", id);
    console.error("publish", error);
    return page("Couldn't publish — try the link again in a minute.", 500);
  }
  return page(`Published: <b>${d === "report" ? "QUESTIONABLE + sources" : String(verdict).toUpperCase()}</b>. The user sees it on their next refresh.`);
});

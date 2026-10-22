// review-decide — Omar's one-tap Approve / Questionable / Reject links from the
// agent email. The tap itself acts and writes the answer into review_requests,
// which the app shows on its next refresh.
//
// approve → the agent's grade, with its verified sources.
// report  → "Questionable" plus every verified source, so the user reads them
//           and decides (the app reports what sources say; it doesn't rule).
// reject  → the request stays open for Omar to answer by hand.
//
// Replies are plain text: Supabase serves every function response as sandboxed
// text/plain, so an HTML confirm page showed as raw code and its button could
// never submit (Oct 22). Omar chose one tap over a confirm step; the decision
// is claimed atomically, so only the first tap (or link pre-fetch) ever counts.

import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const db = createClient("https://abumevloleevhoqxfnoe.supabase.co", Deno.env.get("HALIABLE_SECRET_KEY")!, { auth: { persistSession: false } });
const reply = (body: { message: string }, status = 200) =>
  new Response(body.message + "\n", { status, headers: { "Content-Type": "text/plain; charset=utf-8" } });

Deno.serve(async (r) => {
  const u = new URL(r.url);
  const q = u.searchParams;
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

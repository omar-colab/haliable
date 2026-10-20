// review-decide — Omar's Approve / Reject links from the agent email.
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
  if (!/^[0-9a-f-]{36}$/.test(id) || !/^[0-9a-f-]{36}$/.test(t) || !["approve", "reject"].includes(d)) return page("Bad link.", 400);

  const { data: row } = await db.from("review_agent_drafts").select("*").eq("request_id", id).eq("decision_token", t).maybeSingle();
  if (!row) return page("Link not valid.", 404);
  if (row.status === "approved" || row.status === "rejected") return page(`Already ${row.status}.`);

  if (r.method !== "POST") {
    return page(`<p>${d === "approve" ? `Publish <b>${String(row.draft?.final ?? "").toUpperCase()}</b> to the user?` : "Reject this draft? The request stays open for you to answer by hand."}</p>
      <form method="post"><input type="hidden" name="id" value="${id}"><input type="hidden" name="t" value="${t}"><input type="hidden" name="d" value="${d}">
      <button style="font-size:18px;padding:12px 22px">${d === "approve" ? "✅ Approve" : "❌ Reject"}</button></form>`);
  }

  if (d === "reject") {
    await db.from("review_agent_drafts").update({ status: "rejected", updated_at: new Date().toISOString() }).eq("request_id", id);
    await db.from("review_requests").update({ status: "in_review" }).eq("id", id);
    return page("Rejected. The request is marked in review for you to answer.");
  }

  const draft = row.draft ?? {};
  if (!draft.final) return page("No draft to approve (the agent failed).", 409);
  const best = (draft.sources ?? []).find((s: { verified?: boolean }) => s.verified);
  const reason = [draft.summary, best && `Source: ${best.name} — “${best.quote}” ${best.url}`].filter(Boolean).join("\n\n");
  const { error } = await db.from("review_requests").update({
    status: "completed", verdict: draft.final, verdict_reason: reason,
    evidence: draft.sources, reviewed_at: new Date().toISOString(),
  }).eq("id", id);
  if (error) return page(`Couldn't publish: ${error.message}`, 500);
  await db.from("review_agent_drafts").update({ status: "approved", updated_at: new Date().toISOString() }).eq("request_id", id);
  return page(`Published: <b>${String(draft.final).toUpperCase()}</b>. The user sees it on their next refresh.`);
});

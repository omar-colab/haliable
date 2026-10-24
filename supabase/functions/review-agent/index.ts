// review-agent — fired by the 0012 trigger on every new review request.
//
// One Haiku call with web search reads the label photos, finds a published
// passage that confirms or denies the product, and returns a JSON draft. We
// then fetch each cited page ourselves and keep only quotes that are really
// there (no model can fake that check). The draft is emailed to Omar with
// Approve / Reject links; it reaches the user only through review-decide.
//
// Secrets (supabase secrets set …): ANTHROPIC_API_KEY, RESEND_API_KEY,
// OWNER_EMAIL, HALIABLE_SECRET_KEY (sb_secret_… — legacy service_role JWTs are
// disabled on this project).

import Anthropic from "npm:@anthropic-ai/sdk@0.110.0";
import { createClient } from "npm:@supabase/supabase-js@2.49.4";
import { type Draft, settle } from "../_shared/verdict.ts";
import { verifySources } from "../_shared/page.ts";

const BASE = "https://abumevloleevhoqxfnoe.supabase.co";
const db = createClient(BASE, Deno.env.get("HALIABLE_SECRET_KEY")!, { auth: { persistSession: false } });
const claude = new Anthropic(); // reads ANTHROPIC_API_KEY

const SYSTEM = `You research whether a packaged food is halal for a halal-checking app.
You REPORT what published sources say; you never rule on your own authority.

1. Read the ingredient list from the label photos (and the user's notes).
2. Pick the ONE or TWO ingredients that decide the verdict (e.g. gelatin, carmine,
   E120, E441, rennet, alcohol, mono- and diglycerides, L-cysteine, whey enzymes).
   If nothing questionable is present, say so.
3. Use web search sparingly (at most 3 searches) to find a passage from a
   tier-1 source (a halal body's own published standard or fatwa: JAKIM, MUI,
   IFANCA, HMC, HFSAA, ESMA, SANHA, a manufacturer's halal statement/certificate)
   or tier-2 source (peer-reviewed article). Tier 3 = fatwa aggregators, blogs,
   encyclopedias — orientation only.
4. "quote" MUST be copied word-for-word from the page at "url" (at least 8 words).
   It is checked by machine; paraphrased quotes are discarded.
5. Origin matters: gelatin, enzymes, glycerin, mono/diglycerides, natural flavors
   of unstated origin are "unresolved", not halal. If sources disagree, cite
   both and follow the stricter. Unsure → "unresolved".
6. "graded" lists EVERY ingredient you read with its grade. The app takes the
   worst grade as the product's verdict, so never leave out a doubtful one.

Reply with the JSON object only.`;

const SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["verdict", "ingredients_read", "concern", "summary", "sources", "graded"],
  properties: {
    verdict: { type: "string", enum: ["halal", "doubtful", "haram", "unresolved"] },
    ingredients_read: { type: "string", description: "Ingredients as read from the label" },
    concern: { type: "string", description: "The deciding ingredient(s), or 'none'" },
    graded: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["ingredient", "grade"],
        properties: {
          ingredient: { type: "string" },
          grade: { type: "string", enum: ["halal", "doubtful", "haram", "unresolved"] },
        },
      },
    },
    summary: { type: "string", description: "2-3 sentences a user can read: what the sources say and why" },
    sources: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["name", "url", "tier", "quote"],
        properties: {
          name: { type: "string" },
          url: { type: "string" },
          tier: { type: "integer", enum: [1, 2, 3] },
          quote: { type: "string" },
        },
      },
    },
  },
};

async function research(req: Record<string, unknown>, photoUrls: string[]): Promise<Draft> {
  const content: Anthropic.ContentBlockParam[] = [
    ...photoUrls.map((url) => ({ type: "image" as const, source: { type: "url" as const, url } })),
    { type: "text", text: `Product: ${req.product_name ?? "unknown"}\nBarcode: ${req.barcode ?? "unknown"}\nUser notes: ${req.notes ?? "none"}` },
  ];
  const messages: Anthropic.MessageParam[] = [{ role: "user", content }];
  for (let i = 0; i < 3; i++) {
    const res = await claude.messages.create({
      model: "claude-haiku-5-5",
      max_tokens: 4000,
      system: SYSTEM,
      output_config: { effort: "low", format: { type: "json_schema", schema: SCHEMA } },
      tools: [{ type: "web_search_20250305", name: "web_search", max_uses: 3 }],
      messages,
    } as Anthropic.MessageCreateParamsNonStreaming);
    if (res.stop_reason === "pause_turn") { messages.push({ role: "assistant", content: res.content }); continue; }
    if (res.stop_reason === "refusal") throw new Error("model refused");
    const text = res.content.filter((b) => b.type === "text").map((b) => (b as Anthropic.TextBlock).text).join("");
    return JSON.parse(text) as Draft;
  }
  throw new Error("research paused too many times");
}

async function verify(d: Draft): Promise<Draft> {
  await verifySources(d.sources);
  return d;
}

const esc = (s: unknown) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]!));

async function email(subject: string, html: string) {
  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: "Haliable <onboarding@resend.dev>", to: [Deno.env.get("OWNER_EMAIL")], subject, html }),
  });
  if (!r.ok) console.error("resend", r.status, await r.text());
}

async function run(id: string) {
  // Claim the request. The primary key makes a duplicate trigger a no-op.
  const { data: claim } = await db.from("review_agent_drafts").upsert({ request_id: id }, { onConflict: "request_id", ignoreDuplicates: true }).select("decision_token");
  if (!claim?.length) return;
  const token = claim[0].decision_token;

  const { data: req } = await db.from("review_requests").select("*").eq("id", id).single();
  if (!req) return;
  // Only the requester's own folder (0015 enforces this on insert too).
  const own = (req.photo_paths as string[]).filter((p) => p.startsWith(`${req.user_id}/`) && !p.includes(".."));
  const signed = await Promise.all(own.map(async (p) =>
    (await db.storage.from("review-photos").createSignedUrl(p, 7 * 24 * 3600)).data?.signedUrl));
  const photos = signed.filter(Boolean) as string[];
  const link = (d: string) => `${BASE}/functions/v1/review-decide?id=${id}&t=${token}&d=${d}`;
  const header = `<p><b>${esc(req.product_name || "Unnamed product")}</b> · barcode ${esc(req.barcode || "—")}<br>Notes: ${esc(req.notes || "—")}</p>
    <p>${photos.map((u, i) => `<a href="${esc(u)}">Photo ${i + 1}</a>`).join(" · ")}</p>`;

  try {
    const draft = await verify(await research(req, photos));
    const { verdict, note } = settle(draft);
    await db.from("review_agent_drafts").update({ status: "drafted", draft: { ...draft, final: verdict, note }, updated_at: new Date().toISOString() }).eq("request_id", id);
    const rows = draft.sources.map((s) =>
      `<li>${s.verified ? "✅ quote found on page" : "⚠️ quote NOT found on page"} · Tier ${s.tier} · <a href="${esc(s.url)}">${esc(s.name)}</a><br><i>“${esc(s.quote)}”</i></li>`).join("");
    await email(`[Haliable] ${verdict.toUpperCase()} draft — ${req.product_name || "review request"}`, `${header}
      <h3>Draft verdict: ${verdict.toUpperCase()}</h3>${note ? `<p>⚠️ ${esc(note)}</p>` : ""}
      <p>${esc(draft.summary)}</p>
      <p><b>Deciding ingredient:</b> ${esc(draft.concern)}<br><b>Label read as:</b> ${esc(draft.ingredients_read)}</p>
      <ul>${rows || "<li>No sources found.</li>"}</ul>
      <p>Replying to this email does nothing — tap a button.</p>
      <p><a href="${link("approve")}" style="display:inline-block;padding:14px 22px;background:#1f8a4c;color:#fff;border-radius:10px;text-decoration:none;font-weight:600">✅ Approve &amp; send to user</a>
         &nbsp; <a href="${link("report")}" style="display:inline-block;padding:14px 22px;background:#b7791f;color:#fff;border-radius:10px;text-decoration:none;font-weight:600">🟡 Questionable + sources (user decides)</a>
         &nbsp; <a href="${link("reject")}" style="display:inline-block;padding:14px 22px;background:#b3261e;color:#fff;border-radius:10px;text-decoration:none;font-weight:600">❌ Reject</a></p>
      <p style="font-size:12px;color:#666">If the buttons don't work, open:<br>Approve: ${link("approve")}<br>Questionable: ${link("report")}<br>Reject: ${link("reject")}</p>`);
  } catch (e) {
    console.error(e);
    await db.from("review_agent_drafts").update({ status: "failed", draft: { error: String(e) }, updated_at: new Date().toISOString() }).eq("request_id", id);
    await email(`[Haliable] New review request — agent failed, needs you`, `${header}<p>The agent couldn't finish: ${esc(e)}</p>
      <p>Answer it from the Supabase dashboard (review_requests) or scripts/review-agent.</p>`);
  }
}

Deno.serve(async (r) => {
  const { id } = await r.json().catch(() => ({}));
  if (typeof id !== "string" || !/^[0-9a-f-]{36}$/.test(id)) return new Response("bad id", { status: 400 });
  // Acknowledge at once (the trigger waits 5s at most); research continues.
  // @ts-ignore EdgeRuntime is a Supabase global
  EdgeRuntime.waitUntil(run(id));
  return new Response("queued", { status: 202 });
});

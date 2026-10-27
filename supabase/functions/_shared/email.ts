// Mail to Omar through Resend. Shared by review-agent and daily-digest.
// Secrets: RESEND_API_KEY, OWNER_EMAIL.

export const esc = (s: unknown) =>
  String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]!));

export async function email(subject: string, html: string): Promise<boolean> {
  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: "Haliable <onboarding@resend.dev>", to: [Deno.env.get("OWNER_EMAIL")], subject, html }),
  });
  if (!r.ok) console.error("resend", r.status, await r.text());
  return r.ok;
}

/** A one-tap decision button (review-decide). */
export const button = (href: string, label: string, color: string) =>
  `<a href="${esc(href)}" style="display:inline-block;padding:10px 16px;background:${color};color:#fff;border-radius:8px;text-decoration:none;font-weight:600">${label}</a>`;

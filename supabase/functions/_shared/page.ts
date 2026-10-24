// Fetching the pages a model cited, safely. Shared by review-agent and
// source-scout. Network I/O lives here; the pure rules stay in verdict.ts.

import { type Source, isPrivateIp, isPublicUrl, quoteOnPage } from "./verdict.ts";

/** A source page is text: read at most 3 MB, so a hostile URL can't stream
 *  gigabytes into the function (content-length can be absent or lie). */
async function capped(r: Response, max = 3_000_000): Promise<string> {
  const reader = r.body?.getReader();
  if (!reader) return "";
  const parts: Uint8Array[] = [];
  let size = 0;
  while (size < max) {
    const { done, value } = await reader.read();
    if (done) break;
    parts.push(value); size += value.length;
  }
  await reader.cancel().catch(() => {});
  const all = new Uint8Array(size);
  let at = 0;
  for (const p of parts) { all.set(p, at); at += p.length; }
  return new TextDecoder().decode(all);
}

/** The hostname check can't see where a name points. Resolve it and refuse a
 *  private address. If DNS lookups aren't allowed in this runtime, the
 *  hostname check stands alone (fetch still can't reach Supabase internals). */
async function resolvesPublic(url: string): Promise<boolean> {
  const host = new URL(url).hostname;
  try {
    const ips = (await Promise.all((["A", "AAAA"] as const).map((t) => Deno.resolveDns(host, t).catch(() => [] as string[])))).flat();
    return !ips.some(isPrivateIp);   // no answer → fetch fails on its own
  } catch { return true; }
}

/** Marks each source verified only when its quote is really on its page.
 *  Redirects are followed by hand so every hop passes the SSRF guard — a
 *  public page must not bounce us to an internal one. */
export async function verifySources(sources: Source[]): Promise<void> {
  await Promise.all(sources.map(async (s) => {
    if (!isPublicUrl(s.url)) { s.verified = false; return; }
    try {
      let url = s.url, r: Response | undefined;
      for (let hop = 0; hop < 4 && isPublicUrl(url) && await resolvesPublic(url); hop++) {
        r = await fetch(url, { redirect: "manual", headers: { "User-Agent": "Mozilla/5.0 (Haliable review agent)" }, signal: AbortSignal.timeout(10000) });
        const next = r.status >= 300 && r.status < 400 ? r.headers.get("location") : null;
        if (!next) break;
        url = new URL(next, url).toString(); r = undefined;
      }
      if (!r) { s.verified = false; return; }
      s.verified = r.ok && quoteOnPage(s.quote, await capped(r));
    } catch { s.verified = false; }
  }));
}

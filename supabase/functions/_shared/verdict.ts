// Pure rules shared by the agent and its test. No I/O here.

export type Grade = "halal" | "doubtful" | "haram";
export type Source = { name: string; url: string; tier: number; quote: string; verified?: boolean };
export type Draft = {
  verdict: Grade | "unresolved";
  ingredients_read: string;
  concern: string;
  summary: string;
  sources: Source[];
  /** Every label ingredient the agent graded. The overall verdict is the worst of these. */
  graded?: { ingredient: string; grade: Grade | "unresolved" }[];
};

const RANK = { halal: 0, doubtful: 1, unresolved: 1, haram: 2 } as const;

/** CLAUDE.md rule 4: the product is the WORST of its ingredients, whatever the
 *  model wrote as its headline. "unresolved" counts as doubtful. */
export function worstGrade(d: Draft): Grade | "unresolved" {
  return [d.verdict, ...(d.graded ?? []).map((g) => g.grade)]
    .reduce((a, b) => (RANK[b] > RANK[a] ? b : a));
}

const norm = (s: string) =>
  s.toLowerCase()
    .replace(/&[a-z#0-9]+;/g, " ")
    .replace(/[‘’“”"'`]/g, "")
    .replace(/[^a-z0-9؀-ۿ]+/g, " ")
    .trim();

/** True when the quote really appears on the page (tags stripped, punctuation
 *  and case ignored). A model can invent a passage; it cannot invent this. */
export function quoteOnPage(quote: string, html: string): boolean {
  const q = norm(quote);
  if (q.split(" ").length < 6) return false;            // too short to prove anything
  const page = norm(html.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>/gi, " ")
                         .replace(/<[^>]+>/g, " "));
  return page.includes(q);
}

/** PROTOCOL.md rules 1 + 3: a verdict stands only on a verified tier-1/2 source.
 *  Anything else is "doubtful" — silence is never permission. */
export function settle(d: Draft): { verdict: Grade; note?: string } {
  const backed = d.sources.some((s) => s.verified && (s.tier === 1 || s.tier === 2));
  const worst = worstGrade(d);
  if (worst === "unresolved") return { verdict: "doubtful", note: "Agent could not resolve it." };
  if (!backed) return { verdict: "doubtful", note: `Agent said ${worst}, but no tier-1/2 quote was found on its page.` };
  const note = worst !== d.verdict ? `Agent's headline was ${d.verdict}; worst ingredient grade is ${worst}.` : undefined;
  return { verdict: worst, note };
}

/** SSRF guard: the agent fetches URLs a model chose (and a user's notes can
 *  steer the model), so only public http(s) hostnames — no IPs, no localhost,
 *  no internal names. */
export function isPublicUrl(raw: string): boolean {
  let u: URL;
  try { u = new URL(raw); } catch { return false; }
  if (u.protocol !== "https:" && u.protocol !== "http:") return false;
  if (u.username || u.password || (u.port && u.port !== "80" && u.port !== "443")) return false;
  const h = u.hostname.toLowerCase();
  if (!h.includes(".") || h.endsWith(".local") || h.endsWith(".internal") || h === "localhost") return false;
  if (/^[\d.]+$/.test(h) || h.includes(":") || h.startsWith("[")) return false; // IPv4/IPv6 literals
  return true;
}

/** True for loopback, private, link-local, CGNAT and other non-public IPs —
 *  the second half of the SSRF guard, applied to what a hostname resolves to. */
export function isPrivateIp(ip: string): boolean {
  const v4 = ip.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/);
  if (v4) {
    const [a, b] = [Number(v4[1]), Number(v4[2])];
    return a === 0 || a === 10 || a === 127 || a >= 224 ||
      (a === 100 && b >= 64 && b <= 127) || (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) || (a === 198 && (b === 18 || b === 19));
  }
  const h = ip.toLowerCase();
  if (h.startsWith("::ffff:")) return isPrivateIp(h.slice(7));
  return h === "::" || h === "::1" || /^f[cd]/.test(h) || /^fe[89ab]/.test(h);
}

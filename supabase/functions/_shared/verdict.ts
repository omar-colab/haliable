// Pure rules shared by the agent and its test. No I/O here.

export type Grade = "halal" | "doubtful" | "haram";
export type Source = { name: string; url: string; tier: number; quote: string; verified?: boolean };
export type Draft = {
  verdict: Grade | "unresolved";
  ingredients_read: string;
  concern: string;
  summary: string;
  sources: Source[];
};

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
  if (d.verdict === "unresolved") return { verdict: "doubtful", note: "Agent could not resolve it." };
  if (!backed) return { verdict: "doubtful", note: `Agent said ${d.verdict}, but no tier-1/2 quote was found on its page.` };
  return { verdict: d.verdict };
}

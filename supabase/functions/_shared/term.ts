// The research bot's key for an ingredient. Must match the app's
// SourceScout.normalize (Swift) so both ask for the same row; the shared cases
// in term_test.ts and SourceScoutTests pin that.

export function normalizeTerm(raw: string): string | null {
  const t = raw.replace(/œ/gi, "oe").replace(/æ/gi, "ae").replace(/ß/g, "ss").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase()
    .replace(/[^a-z0-9 -]+/g, " ").replace(/\s+/g, " ").trim().replace(/^[ -]+/, "");
  if (t.length < 2 || t.length > 60 || t.split(" ").length > 6) return null;
  return t;
}

type Known = { status: string; sources?: unknown[] | null; updated_at: string };

/** Whether a term should be (re)searched: never seen, a failure older than a
 *  day, or an empty result older than 30 days (sources get published). */
export function needsResearch(k: Known | undefined, now = Date.now()): boolean {
  if (!k) return true;
  const age = now - Date.parse(k.updated_at);
  if (k.status === "failed") return age > 86_400_000;
  return k.status === "done" && !(k.sources?.length) && age > 30 * 86_400_000;
}

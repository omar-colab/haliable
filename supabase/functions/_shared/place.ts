// Pure rules for the place agent. No I/O here.

import { type Source } from "./verdict.ts";

export type MenuItem = { item: string; status: "halal" | "pork" | "alcohol" | "unclear" };
export type PlaceDraft = { verdict: string; certifier: string; menu: MenuItem[]; summary: string; sources: Source[] };

export const SCOPES = ["fully_halal", "halal_meat_only", "halal_options"];

/** One lookup per place for everyone: name + coordinates to ~100 m. */
export function placeKey(name: string, lat: number, lng: number): string {
  const n = name.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim().slice(0, 120);
  return `${n}|${lat.toFixed(3)}|${lng.toFixed(3)}`;
}

/** Report, don't rule: a place is listable only on a machine-verified tier-1
 *  (certifier) or tier-2 (the place's own site/menu) quote. Pork or alcohol on
 *  the menu means it can't be "fully halal" — at most "halal options". */
export function settlePlace(d: PlaceDraft): string {
  if (!SCOPES.includes(d.verdict)) return d.verdict === "not_halal" ? "not_halal" : "unknown";
  if (!d.sources.some((s) => s.verified && (s.tier === 1 || s.tier === 2))) return "unknown";
  const haram = d.menu.some((m) => m.status === "pork" || m.status === "alcohol");
  return haram && d.verdict !== "halal_options" ? "halal_options" : d.verdict;
}

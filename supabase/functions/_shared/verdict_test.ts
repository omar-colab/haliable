import { quoteOnPage, settle } from "./verdict.ts";
const eq = (a: unknown, b: unknown) => { if (JSON.stringify(a) !== JSON.stringify(b)) throw new Error(`${JSON.stringify(a)} != ${JSON.stringify(b)}`); };

Deno.test("quote must really be on the page", () => {
  const page = `<p>Gelatin derived from <b>pork</b> is haram; gelatin from zabiha cattle is halal.</p><script>x</script>`;
  eq(quoteOnPage("gelatin derived from pork is haram; gelatin from zabiha", page), true);
  eq(quoteOnPage("gelatin derived from pork is permissible for all Muslims", page), false);
  eq(quoteOnPage("pork is haram", page), false); // too short to prove anything
});

Deno.test("no verified tier-1/2 source → doubtful, never halal", () => {
  const base = { ingredients_read: "", concern: "", summary: "" };
  eq(settle({ ...base, verdict: "halal", sources: [{ name: "x", url: "u", tier: 3, quote: "q", verified: true }] }).verdict, "doubtful");
  eq(settle({ ...base, verdict: "halal", sources: [{ name: "x", url: "u", tier: 1, quote: "q", verified: false }] }).verdict, "doubtful");
  eq(settle({ ...base, verdict: "haram", sources: [{ name: "x", url: "u", tier: 2, quote: "q", verified: true }] }).verdict, "haram");
  eq(settle({ ...base, verdict: "unresolved", sources: [] }).verdict, "doubtful");
});

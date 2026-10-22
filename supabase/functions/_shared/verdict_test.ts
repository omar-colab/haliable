import { isPrivateIp, quoteOnPage, settle } from "./verdict.ts";
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

Deno.test("verdict is the worst ingredient, not the model's headline", () => {
  const src = [{ name: "x", url: "u", tier: 1, quote: "q", verified: true }];
  const base = { ingredients_read: "", concern: "", summary: "", sources: src };
  eq(settle({ ...base, verdict: "halal", graded: [{ ingredient: "sugar", grade: "halal" }, { ingredient: "pork gelatin", grade: "haram" }] }).verdict, "haram");
  eq(settle({ ...base, verdict: "halal", graded: [{ ingredient: "natural flavors", grade: "unresolved" }] }).verdict, "doubtful");
  eq(settle({ ...base, verdict: "halal", graded: [{ ingredient: "sugar", grade: "halal" }] }).verdict, "halal");
});

Deno.test("agent only fetches public web pages", async () => {
  const { isPublicUrl } = await import("./verdict.ts");
  eq(isPublicUrl("https://www.ifanca.org/gelatin"), true);
  for (const bad of ["http://169.254.169.254/latest", "http://localhost:54321", "http://[::1]/", "file:///etc/passwd",
                     "http://db.internal/x", "https://user:pw@example.com", "http://example.com:5432", "http://intranet/"])
    eq([bad, isPublicUrl(bad)], [bad, false]);
});

Deno.test("private and internal IPs are refused, public ones pass", () => {
  for (const ip of ["127.0.0.1", "10.1.2.3", "172.20.0.1", "192.168.1.1", "169.254.169.254", "100.64.0.1", "0.0.0.0", "::1", "fd00::1", "fe80::1", "::ffff:127.0.0.1"]) {
    eq([ip, isPrivateIp(ip)], [ip, true]);
  }
  for (const ip of ["8.8.8.8", "172.32.0.1", "2606:4700::1111"]) eq([ip, isPrivateIp(ip)], [ip, false]);
});

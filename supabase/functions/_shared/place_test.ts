import { assertEquals } from "jsr:@std/assert@1";
import { placeKey, settlePlace } from "./place.ts";

const src = (tier: number, verified: boolean) => ({ name: "x", url: "https://a.com", tier, quote: "q", verified });

Deno.test("place key folds case and rounds coords", () => {
  assertEquals(placeKey("Al-Noor  Grill!", 41.80891, -72.25004), "al noor grill|41.809|-72.250");
});

Deno.test("no verified tier-1/2 source → unknown", () => {
  assertEquals(settlePlace({ verdict: "fully_halal", certifier: "", menu: [], summary: "", sources: [src(3, true), src(1, false)] }), "unknown");
});

Deno.test("pork on the menu caps a 'fully halal' claim at halal options", () => {
  const menu = [{ item: "bacon burger", status: "pork" as const }];
  assertEquals(settlePlace({ verdict: "fully_halal", certifier: "HFSAA", menu, summary: "", sources: [src(1, true)] }), "halal_options");
});

Deno.test("verified certifier keeps its scope; not_halal passes through", () => {
  assertEquals(settlePlace({ verdict: "halal_meat_only", certifier: "HMC", menu: [], summary: "", sources: [src(1, true)] }), "halal_meat_only");
  assertEquals(settlePlace({ verdict: "not_halal", certifier: "", menu: [], summary: "", sources: [] }), "not_halal");
});

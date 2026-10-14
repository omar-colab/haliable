# QA checklist — run this before the demo

Phase 6. Tap-by-tap, on the **device you will demo from**, on the **network you
will demo on** (campus wifi *and* cellular — run it twice). Takes ~15 minutes.

Mark each line. A ❌ on anything in **bold** means don't demo that path.

| # | Where | Do this | Expect | ✅/❌ |
|---|---|---|---|---|
| 1 | cold start | Force-quit, reopen | Launch intro, then **Scan** tab. No white flash, no crash | |
| 2 | Scan | Read the header | `Haliable` wordmark + `HALAL SCANNER`, gear top-right | |
| 3 | Scan | Tap the standard pill | Sheet lists **Zabiha-only / Hanafi-strict / General Halal / Lenient** with one-line descriptions | |
| 4 | Scan | Pick General Halal, close | Pill now reads `General Halal` | |
| 5 | Scan | **Tap "Start scanning"** | Camera permission prompt (first run only) → live preview with reticle inside 2s | |
| 6 | Scan | **Scan demo barcode #1** (see `DEMO_SCRIPT.md`) | Verdict sheet opens < 3s. Product name + brand are the real ones | |
| 7 | Verdict | Read the badge | Grade matches the probe output in `DEMO_SCRIPT.md` for that barcode | |
| 8 | Verdict | Scroll to "What we flagged" | Flagged ingredient(s) listed, worst one first. If nothing: "Nothing flagged" | |
| 9 | Verdict | **Tap a flagged ingredient** | Citation shows: `reference · date`. Not blank, not "pending" on a demo barcode | |
| 10 | Verdict | Dismiss, change standard, rescan | **Verdict changes** on the divergent barcode. This is the demo's money shot | |
| 11 | Scan | Tap "Enter barcode manually", type a demo barcode, "Look up" | Same verdict sheet as scanning. This is the fallback if the camera misbehaves | |
| 12 | Scan | Enter `0000000000000` | A clear not-found message. **No crash, no spinner forever** | |
| 13 | Scan | Airplane mode on, look up a barcode | An offline message, not a wrong verdict | |
| 14 | — | Airplane mode off | | |
| 15 | Find | Open the tab | Map loads, centred near you. Legend: Fully halal / Halal meat / Halal options | |
| 16 | Find | Allow location when asked | **Store pins appear.** On campus: the 5 real UConn locations. If zero pins → Supabase is down or paused | |
| 17 | Find | Tap a pin | Store detail: name, address, what makes it halal. No "demo"/"test" names | |
| 18 | Find | Tap `+` | Submit-a-place form opens; cancel out of it | |
| 19 | Reviews | Open the tab | Either "Sign in to request reviews" or your requests. Signed out is fine to demo | |
| 20 | History | Open the tab | Today's scans are listed, newest first; streak count shown | |
| 21 | About | Open the tab | Methodology reachable; Acknowledgements lists the five bundled fonts | |
| 22 | Settings (gear) | Open it | Standard picker here matches the Scan pill (change one, check the other) | |
| 23 | whole app | Rotate / go to Home and back | State survives; no crash | |
| 24 | battery | Check | > 50% before you walk in, and bring the cable | |

## If something fails

- **No pins on the map** → the Supabase free project paused. The keep-alive Action
  prevents this; check its last run is green:
  `gh run list --workflow "Supabase keep-alive" --repo omar-colab/haliable -L 3`
- **Barcode resolves but no ingredients** → that product is a bad demo pick. Swap it
  using the probe (see `DEMO_SCRIPT.md` → "Re-run the probe").
- **Camera won't start** → use manual entry (#11). Never debug live; switch and move on.
- **Verdict says draft / needs review** → that's correct behaviour, not a bug. Say so
  out loud: the app reports what scholars said and marks what isn't cited yet.

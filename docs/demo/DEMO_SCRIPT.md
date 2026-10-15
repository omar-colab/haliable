# Demo script — Haliable

Phase 6. Three lengths: 3 minutes, 60 seconds, 30 seconds. Pick by how much
room you're given and don't improvise a longer one.

Run `./scripts/run-demo-probe.sh` **the morning of the demo**. These are
third-party databases; a product can change or vanish overnight. The probe takes
about a minute and tells you exactly which barcode to drop.

---

## The kit — 6 barcodes, verified Oct 14, 2026

| # | Product | Barcode | What it proves |
|---|---|---|---|
| 1 | Oreo | `044000032029` | Clean pass. **Halal under all four standards** |
| 2 | Jif Creamy Peanut Butter | `0051500255162` | **Diverges**, and the citation is live — not a draft |
| 3 | Yoplait Original red raspberry | `070470003016` | The money shot: **haram under Zabiha-only, doubtful under the other three** |
| 4 | Welch's Fruit Snacks | `0034856008187` | **Haram under all four.** The app doesn't hedge when it shouldn't. **Don't tap into the citation on this one** — see below |
| 5 | Cheetos XXtra Flamin' Hot | `028400433303` | **Diverges** on enzymes / whey |
| 6 | Diet Coke | `0049000028911` | Shows a **draft** grade — the honest "no citation yet" state |

What each one actually printed:

```
1  Oreo                     halal / halal / halal / halal              (nothing flagged)
2  Jif Creamy PB            mashboohDisapproved ×2, mashboohContested ×2
                            driver: "Mono- and diglycerides"           ← cited, not a draft
3  Yoplait red raspberry    zabiha: haram          driver: "kosher gelatin"
                            other three: mashboohDisapproved (draft)   driver: E428
4  Welch's Fruit Snacks     haram / haram / haram / haram  (all four marked draft)
                            driver: "pork"   ← haram everywhere, but NOT a citation
5  Cheetos XXtra Flamin'Hot zabiha: haram          driver: enzymes
                            other three: mashboohDisapproved / Contested ×2, driver: whey
6  Diet Coke                mashboohDisapproved ×2, mashboohContested ×2 (draft)
                            driver: E150C                              ← no citation yet
```

Order (strictness-ordered from `HalalStandard.strictnessRank`):
**Zabiha-only → Hanafi-strict → General Halal → Lenient.**

---

## 3 minutes

**0:00 — the problem (20s).** "I'm Muslim. Every time I pick up a packaged
product I'm reading an ingredient list for things like gelatin, mono- and
diglycerides, enzymes — and even then the answer depends on which scholar you
follow. There's no app that tells you *whose* ruling it's giving you."

**0:20 — a clean scan (25s).** Scan **#1 Oreo**. Verdict comes back halal.
"Nothing flagged. That's the easy case."

**0:45 — the real case (40s).** Scan **#2 Jif**. It comes back doubtful on
mono- and diglycerides. Tap the flagged ingredient. "This isn't my opinion — it's
a published ruling, with the source and the date. The app reports what scholars
said; it doesn't decide."

**1:25 — the money shot (45s).** Scan **#3 Yoplait**. Switch the standard pill
from General Halal to **Zabiha-only**. The verdict changes to **haram** on the
gelatin. "Same product, same ingredients, different school of thought — and the
app says so out loud instead of pretending there's one answer."

**2:10 — where it doesn't hedge (20s).** Scan **#4 Welch's Fruit Snacks**.
Haram under all four. "When it's clear, it's clear."

**2:30 — the map (20s).** Find tab. Real halal locations near campus, pulled
live from the backend, with a community submit button.

**2:50 — honesty (10s).** Show **#6 Diet Coke**, marked a draft. "Where no
scholar has ruled on an additive yet, it says so rather than guessing. 123 cells
are cited; the rest are marked. A false halal is the one error I won't ship."

---

## 60 seconds

1. **#1 Oreo** — clean halal. (10s)
2. **#3 Yoplait** — doubtful under General Halal; switch to **Zabiha-only**, it
   turns haram. Tap the gelatin, show the citation. (35s)
3. **Find tab** — real stores near campus. (10s)
4. One line: "Every judgement carries a published source, and anything uncited is
   marked as a draft rather than guessed at." (5s)

## 30 seconds

Scan **#3 Yoplait**, flip the standard, show the verdict change and the citation
behind it. Nothing else. That one interaction is the whole product.

---

## Don't be surprised by

- **Slot 4 is your "clear haram" moment, not your citation moment.** Re-probed Oct 15
  after the ingredient-matcher fix: Welch's now reports `haram (draft)` under all four
  standards, driven by **pork**. The verdict is right and that's what you're showing.
  But pork reading as *uncited* looks wrong to anyone who taps it, so do the citation
  moment on **#2 Jif** or **#3 Yoplait under Zabiha** — both are cited and neither is a
  draft. (Worth closing the pork citation gap after the interview; it's a gap in
  `Citations.json`, not a bug in the engine.)
- **Draft / "needs review" labels are correct.** 123 citation cells are filled;
  additives without a published ruling stay marked. Say it out loud — it's the
  strongest thing about the app, not a gap to hide.
- **The driver ingredient can shift between runs** when two ingredients tie at the
  same grade (Cheetos showed `enzymes` in one run and `whey` in the next). The
  *grade* is stable; the named driver may not be. Don't promise a specific word.
- **The same barcode can resolve from USDA or Open Food Facts** depending on which
  answers first, and the two have different ingredient text. Goya `041331092609`
  graded `mashboohContested` on one run and `halal` on the next for exactly this
  reason — which is why it is **not** in the kit.
- **Nothing in the kit uses the camera-free path by accident.** If the camera
  misbehaves, tap "Enter barcode manually" and type the number. Practise that once.

## Barcodes that did NOT work — don't retry these live

`070462098068` Sour Patch Kids · `036632071156` Dannon Light & Fit ·
`022000106506` Skittles · `052100001715` McCormick vanilla extract ·
`072250011495` Nature's Own bread — all 404. `072250007214` resolves with **zero**
ingredient text. `041331092609` Goya — unstable, see above.

## Still to do (yours)

- [ ] Buy the six products, or find them in a store you can stand in.
- [ ] Three dry runs **on cellular**, not campus wifi.
- [ ] Two out-loud reps of the 60-second version.
- [ ] A backup screen recording of the 60-second version, on your phone, offline.
- [ ] `docs/demo/QA_CHECKLIST.md` run end to end on the demo device.

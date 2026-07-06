# Haliable — Sourced-Research Worksheet (REPORT, DON'T RULE)

> **A research worksheet, not a fatwa and not the app's own ruling.**
> Haliable reports *published* positions with citations the user can check —
> never a bare "halal/haram" in its own voice. Research each cell against a
> published source, record the citation in `Citations.json`, and the cell
> clears. Uncited cells stay visibly pending; the app ships with whatever
> subset is cited, never guessed.

Generated from the live `GradeMatrix` + `Citations.json` on
**2026-06-20** — 124 cells; **0 cited, 0 need a 2nd source, 124 pending** (0 citations on file). Ordered: high-traffic first, then category order (no request data supplied yet). Regenerate after any change.

**Clearance gate (enforced in code + tests):** a cell clears ONLY with
≥1 **tier-1/2** citation carrying source name + reference + date + paraphrase.
**High-traffic cells, and every `lenient` cell, need ≥2 INDEPENDENT sources.**
An **origin-undeterminable** cell (origin not on a US label) can never clear to
halal — only to a documented non-halal grade. Tier 3 supports but never clears.

**Source tiers:** 1 = the standard body's own published document (JAKIM/MUI/ESMA/SMIIC, IFANCA/HMC/HFSAA) · 2 = peer-reviewed scholarship (journal / Google Scholar) · 3 = reputable secondary explainer (orienting only).

**Per-cell procedure:** identify the position's governing body → find its tier-1 stance on this subject/origin → capture name, reference (URL/doc + clause), date, tier, and a paraphrase of what it says → set the grade → for high-traffic/lenient, find a 2nd independent source → if sources split within the position, mark contested with both citations.

> _Standing disclosure shown in-app on every verdict:_
> **Sourced from published halal standards and scholarly references — verify with a scholar you trust for your situation.**

---


## 0. OPEN LEVERS — high-leverage pending cells

Four calls with no seeded row / single answer yet. They are ordinary
pending cells (no special status) — research each against a published
source and cite it like any other. Listed first because they're consequential.


### Seafood / non-fish seafood lever

- **Question:** What grade does non-fish seafood (shrimp, crab, shellfish, squid, …) take under each of the four positions — and does hanafiStrict escalate it (fish-only)?
- **Current behavior in code:** UNSET — no `category(.seafoodNonFish)` row is seeded, so it currently falls to the conservative fallback (Questionable — contested) under every position. The old fish-only escalation under hanafiStrict is NOT reproduced.
- **Source name / reference / date / tier:** _______________________________
- **Paraphrase (what the source says):** ___________________________________
<!--lever:seafood-non-fish-->


### Bare-alcohol tier

- **Question:** What grade applies to alcohol/ethanol that is neither confirmed khamr nor a confirmed <0.5% non-khamr carrier (i.e. presence known, source/quantity unknown)?
- **Current behavior in code:** UNSET — confirmed khamr tokens hit the hard-haram pin (Haram, all positions); a named non-khamr carrier uses the vanilla-extract tier. The in-between 'bare alcohol' case has no dedicated tier and currently rides the generic alcohol-carrier row.
- **Source name / reference / date / tier:** _______________________________
- **Paraphrase (what the source says):** ___________________________________
<!--lever:bare-alcohol-tier-->


### Certifier meat / non-meat split

- **Question:** Should a body's satisfaction set differ for meat vs non-meat products (e.g. a body trusted for additives but not for its slaughter standard)?
- **Current behavior in code:** UNSET — each `CertificationBody` exposes a SINGLE `confidentlySatisfies` set with no meat/non-meat distinction. `uncertainlySatisfies` is empty pending this call.
- **Source name / reference / date / tier:** _______________________________
- **Paraphrase (what the source says):** ___________________________________
<!--lever:certifier-meat-split-->


### Confidence levels

- **Question:** Confirm the `Confidence` value on each seeded cell (drives how assertively the UI may speak once a cell is signed off).
- **Current behavior in code:** UNSET as authoritative — seeded cells currently carry: medium. All are draft.
- **Source name / reference / date / tier:** _______________________________
- **Paraphrase (what the source says):** ___________________________________
<!--lever:confidence-->


---


## 1. Per-cell research worksheet — one row per cell

High-traffic cells first (`★`). Status: **CITED** (cleared) · **NEEDS 2ND SOURCE**
(one strong source, needs a second independent one) · **PENDING** (uncited).

| ★ | Subject | Origin | Position | Governing body | Current grade | Citation status | Paraphrase (on file) |
|---|---|---|---|---|---|---|---|
| ★ | enzyme | animal | Zabiha-only | HMC / HFSAA | 5 — Haram | PENDING |  | <!--cell:enzyme::animal::zabiha-->
| ★ | enzyme | animal | Hanafi-strict | JAKIM / MUI / ESMA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:enzyme::animal::hanafiStrict-->
| ★ | enzyme | animal | General Halal | IFANCA / ISNA | 3 — Questionable — contested | PENDING |  | <!--cell:enzyme::animal::general-->
| ★ | enzyme | animal | Lenient | most permissive published scholarly position (needs 2 sources) | 3 — Questionable — contested | PENDING |  | <!--cell:enzyme::animal::lenient-->
| ★ | enzyme | microbial | Zabiha-only | HMC / HFSAA | 1 — Halal | PENDING |  | <!--cell:enzyme::microbial::zabiha-->
| ★ | enzyme | microbial | Hanafi-strict | JAKIM / MUI / ESMA | 1 — Halal | PENDING |  | <!--cell:enzyme::microbial::hanafiStrict-->
| ★ | enzyme | microbial | General Halal | IFANCA / ISNA | 1 — Halal | PENDING |  | <!--cell:enzyme::microbial::general-->
| ★ | enzyme | microbial | Lenient | most permissive published scholarly position (needs 2 sources) | 1 — Halal | PENDING |  | <!--cell:enzyme::microbial::lenient-->
| ★ | enzyme | unspecified | Zabiha-only | HMC / HFSAA | 5 — Haram | PENDING |  | <!--cell:enzyme::unspecified::zabiha-->
| ★ | enzyme | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:enzyme::unspecified::hanafiStrict-->
| ★ | enzyme | unspecified | General Halal | IFANCA / ISNA | 3 — Questionable — contested | PENDING |  | <!--cell:enzyme::unspecified::general-->
| ★ | enzyme | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 3 — Questionable — contested | PENDING |  | <!--cell:enzyme::unspecified::lenient-->
| ★ | gelatin | plant | Zabiha-only | HMC / HFSAA | 1 — Halal | PENDING |  | <!--cell:gelatin::plant::zabiha-->
| ★ | gelatin | plant | Hanafi-strict | JAKIM / MUI / ESMA | 1 — Halal | PENDING |  | <!--cell:gelatin::plant::hanafiStrict-->
| ★ | gelatin | plant | General Halal | IFANCA / ISNA | 1 — Halal | PENDING |  | <!--cell:gelatin::plant::general-->
| ★ | gelatin | plant | Lenient | most permissive published scholarly position (needs 2 sources) | 1 — Halal | PENDING |  | <!--cell:gelatin::plant::lenient-->
| ★ | gelatin | animalNonZabiha | Zabiha-only | HMC / HFSAA | 5 — Haram | PENDING |  | <!--cell:gelatin::animalNonZabiha::zabiha-->
| ★ | gelatin | animalNonZabiha | Hanafi-strict | JAKIM / MUI / ESMA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:gelatin::animalNonZabiha::hanafiStrict-->
| ★ | gelatin | animalNonZabiha | General Halal | IFANCA / ISNA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:gelatin::animalNonZabiha::general-->
| ★ | gelatin | animalNonZabiha | Lenient | most permissive published scholarly position (needs 2 sources) | 4 — Questionable — widely avoided | PENDING |  | <!--cell:gelatin::animalNonZabiha::lenient-->
| ★ | gelatin | microbial | Zabiha-only | HMC / HFSAA | 1 — Halal | PENDING |  | <!--cell:gelatin::microbial::zabiha-->
| ★ | gelatin | microbial | Hanafi-strict | JAKIM / MUI / ESMA | 1 — Halal | PENDING |  | <!--cell:gelatin::microbial::hanafiStrict-->
| ★ | gelatin | microbial | General Halal | IFANCA / ISNA | 1 — Halal | PENDING |  | <!--cell:gelatin::microbial::general-->
| ★ | gelatin | microbial | Lenient | most permissive published scholarly position (needs 2 sources) | 1 — Halal | PENDING |  | <!--cell:gelatin::microbial::lenient-->
| ★ | gelatin | unspecified | Zabiha-only | HMC / HFSAA | 5 — Haram | PENDING |  | <!--cell:gelatin::unspecified::zabiha-->
| ★ | gelatin | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:gelatin::unspecified::hanafiStrict-->
| ★ | gelatin | unspecified | General Halal | IFANCA / ISNA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:gelatin::unspecified::general-->
| ★ | gelatin | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 4 — Questionable — widely avoided | PENDING |  | <!--cell:gelatin::unspecified::lenient-->
| ★ | whey | unspecified | Zabiha-only | HMC / HFSAA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:whey::unspecified::zabiha-->
| ★ | whey | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 3 — Questionable — contested | PENDING |  | <!--cell:whey::unspecified::hanafiStrict-->
| ★ | whey | unspecified | General Halal | IFANCA / ISNA | 3 — Questionable — contested | PENDING |  | <!--cell:whey::unspecified::general-->
| ★ | whey | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 3 — Questionable — contested | PENDING |  | <!--cell:whey::unspecified::lenient-->
| ★ | E120 | unspecified | Zabiha-only | HMC / HFSAA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E120::unspecified::zabiha-->
| ★ | E120 | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E120::unspecified::hanafiStrict-->
| ★ | E120 | unspecified | General Halal | IFANCA / ISNA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E120::unspecified::general-->
| ★ | E120 | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 2 — Questionable — widely accepted | PENDING |  | <!--cell:E120::unspecified::lenient-->
| ★ | alcohol | unspecified | Zabiha-only | HMC / HFSAA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:alcohol::unspecified::zabiha-->
| ★ | alcohol | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:alcohol::unspecified::hanafiStrict-->
| ★ | alcohol | unspecified | General Halal | IFANCA / ISNA | 3 — Questionable — contested | PENDING |  | <!--cell:alcohol::unspecified::general-->
| ★ | alcohol | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 2 — Questionable — widely accepted | PENDING |  | <!--cell:alcohol::unspecified::lenient-->
| ★ | flavor ethanol carrier | unspecified | Zabiha-only | HMC / HFSAA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:flavor ethanol carrier::unspecified::zabiha-->
| ★ | flavor ethanol carrier | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:flavor ethanol carrier::unspecified::hanafiStrict-->
| ★ | flavor ethanol carrier | unspecified | General Halal | IFANCA / ISNA | 2 — Questionable — widely accepted | PENDING |  | <!--cell:flavor ethanol carrier::unspecified::general-->
| ★ | flavor ethanol carrier | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 1 — Halal | PENDING |  | <!--cell:flavor ethanol carrier::unspecified::lenient-->
| ★ | vanilla extract | unspecified | Zabiha-only | HMC / HFSAA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:vanilla extract::unspecified::zabiha-->
| ★ | vanilla extract | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:vanilla extract::unspecified::hanafiStrict-->
| ★ | vanilla extract | unspecified | General Halal | IFANCA / ISNA | 3 — Questionable — contested | PENDING |  | <!--cell:vanilla extract::unspecified::general-->
| ★ | vanilla extract | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 2 — Questionable — widely accepted | PENDING |  | <!--cell:vanilla extract::unspecified::lenient-->
| ★ | E322 | plant | Zabiha-only | HMC / HFSAA | 1 — Halal | PENDING |  | <!--cell:E322::plant::zabiha-->
| ★ | E322 | plant | Hanafi-strict | JAKIM / MUI / ESMA | 1 — Halal | PENDING |  | <!--cell:E322::plant::hanafiStrict-->
| ★ | E322 | plant | General Halal | IFANCA / ISNA | 1 — Halal | PENDING |  | <!--cell:E322::plant::general-->
| ★ | E322 | plant | Lenient | most permissive published scholarly position (needs 2 sources) | 1 — Halal | PENDING |  | <!--cell:E322::plant::lenient-->
| ★ | E322 | unspecified | Zabiha-only | HMC / HFSAA | 2 — Questionable — widely accepted | PENDING |  | <!--cell:E322::unspecified::zabiha-->
| ★ | E322 | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 2 — Questionable — widely accepted | PENDING |  | <!--cell:E322::unspecified::hanafiStrict-->
| ★ | E322 | unspecified | General Halal | IFANCA / ISNA | 2 — Questionable — widely accepted | PENDING |  | <!--cell:E322::unspecified::general-->
| ★ | E322 | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 2 — Questionable — widely accepted | PENDING |  | <!--cell:E322::unspecified::lenient-->
| ★ | E422 | unspecified | Zabiha-only | HMC / HFSAA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E422::unspecified::zabiha-->
| ★ | E422 | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E422::unspecified::hanafiStrict-->
| ★ | E422 | unspecified | General Halal | IFANCA / ISNA | 3 — Questionable — contested | PENDING |  | <!--cell:E422::unspecified::general-->
| ★ | E422 | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 3 — Questionable — contested | PENDING |  | <!--cell:E422::unspecified::lenient-->
| ★ | E470 | unspecified | Zabiha-only | HMC / HFSAA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E470::unspecified::zabiha-->
| ★ | E470 | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 3 — Questionable — contested | PENDING |  | <!--cell:E470::unspecified::hanafiStrict-->
| ★ | E470 | unspecified | General Halal | IFANCA / ISNA | 3 — Questionable — contested | PENDING |  | <!--cell:E470::unspecified::general-->
| ★ | E470 | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 3 — Questionable — contested | PENDING |  | <!--cell:E470::unspecified::lenient-->
| ★ | E471 | unspecified | Zabiha-only | HMC / HFSAA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E471::unspecified::zabiha-->
| ★ | E471 | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E471::unspecified::hanafiStrict-->
| ★ | E471 | unspecified | General Halal | IFANCA / ISNA | 3 — Questionable — contested | PENDING |  | <!--cell:E471::unspecified::general-->
| ★ | E471 | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 3 — Questionable — contested | PENDING |  | <!--cell:E471::unspecified::lenient-->
|  | meat | animalNonZabiha | Zabiha-only | HMC / HFSAA | 5 — Haram | PENDING |  | <!--cell:meat::animalNonZabiha::zabiha-->
|  | meat | animalNonZabiha | Hanafi-strict | JAKIM / MUI / ESMA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:meat::animalNonZabiha::hanafiStrict-->
|  | meat | animalNonZabiha | General Halal | IFANCA / ISNA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:meat::animalNonZabiha::general-->
|  | meat | animalNonZabiha | Lenient | most permissive published scholarly position (needs 2 sources) | 4 — Questionable — widely avoided | PENDING |  | <!--cell:meat::animalNonZabiha::lenient-->
|  | meat | unspecified | Zabiha-only | HMC / HFSAA | 5 — Haram | PENDING |  | <!--cell:meat::unspecified::zabiha-->
|  | meat | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:meat::unspecified::hanafiStrict-->
|  | meat | unspecified | General Halal | IFANCA / ISNA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:meat::unspecified::general-->
|  | meat | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 4 — Questionable — widely avoided | PENDING |  | <!--cell:meat::unspecified::lenient-->
|  | E901 | unspecified | Zabiha-only | HMC / HFSAA | 1 — Halal | PENDING |  | <!--cell:E901::unspecified::zabiha-->
|  | E901 | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 1 — Halal | PENDING |  | <!--cell:E901::unspecified::hanafiStrict-->
|  | E901 | unspecified | General Halal | IFANCA / ISNA | 1 — Halal | PENDING |  | <!--cell:E901::unspecified::general-->
|  | E901 | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 1 — Halal | PENDING |  | <!--cell:E901::unspecified::lenient-->
|  | E904 | unspecified | Zabiha-only | HMC / HFSAA | 3 — Questionable — contested | PENDING |  | <!--cell:E904::unspecified::zabiha-->
|  | E904 | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 3 — Questionable — contested | PENDING |  | <!--cell:E904::unspecified::hanafiStrict-->
|  | E904 | unspecified | General Halal | IFANCA / ISNA | 3 — Questionable — contested | PENDING |  | <!--cell:E904::unspecified::general-->
|  | E904 | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 3 — Questionable — contested | PENDING |  | <!--cell:E904::unspecified::lenient-->
|  | E153 | unspecified | Zabiha-only | HMC / HFSAA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E153::unspecified::zabiha-->
|  | E153 | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 3 — Questionable — contested | PENDING |  | <!--cell:E153::unspecified::hanafiStrict-->
|  | E153 | unspecified | General Halal | IFANCA / ISNA | 3 — Questionable — contested | PENDING |  | <!--cell:E153::unspecified::general-->
|  | E153 | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 3 — Questionable — contested | PENDING |  | <!--cell:E153::unspecified::lenient-->
|  | E472 | unspecified | Zabiha-only | HMC / HFSAA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E472::unspecified::zabiha-->
|  | E472 | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E472::unspecified::hanafiStrict-->
|  | E472 | unspecified | General Halal | IFANCA / ISNA | 3 — Questionable — contested | PENDING |  | <!--cell:E472::unspecified::general-->
|  | E472 | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 3 — Questionable — contested | PENDING |  | <!--cell:E472::unspecified::lenient-->
|  | E542 | unspecified | Zabiha-only | HMC / HFSAA | 5 — Haram | PENDING |  | <!--cell:E542::unspecified::zabiha-->
|  | E542 | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E542::unspecified::hanafiStrict-->
|  | E542 | unspecified | General Halal | IFANCA / ISNA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E542::unspecified::general-->
|  | E542 | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E542::unspecified::lenient-->
|  | E570 | unspecified | Zabiha-only | HMC / HFSAA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E570::unspecified::zabiha-->
|  | E570 | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 3 — Questionable — contested | PENDING |  | <!--cell:E570::unspecified::hanafiStrict-->
|  | E570 | unspecified | General Halal | IFANCA / ISNA | 3 — Questionable — contested | PENDING |  | <!--cell:E570::unspecified::general-->
|  | E570 | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 3 — Questionable — contested | PENDING |  | <!--cell:E570::unspecified::lenient-->
|  | E627 | unspecified | Zabiha-only | HMC / HFSAA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E627::unspecified::zabiha-->
|  | E627 | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 3 — Questionable — contested | PENDING |  | <!--cell:E627::unspecified::hanafiStrict-->
|  | E627 | unspecified | General Halal | IFANCA / ISNA | 3 — Questionable — contested | PENDING |  | <!--cell:E627::unspecified::general-->
|  | E627 | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 3 — Questionable — contested | PENDING |  | <!--cell:E627::unspecified::lenient-->
|  | E631 | unspecified | Zabiha-only | HMC / HFSAA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E631::unspecified::zabiha-->
|  | E631 | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 3 — Questionable — contested | PENDING |  | <!--cell:E631::unspecified::hanafiStrict-->
|  | E631 | unspecified | General Halal | IFANCA / ISNA | 3 — Questionable — contested | PENDING |  | <!--cell:E631::unspecified::general-->
|  | E631 | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 3 — Questionable — contested | PENDING |  | <!--cell:E631::unspecified::lenient-->
|  | E920 | animal | Zabiha-only | HMC / HFSAA | 5 — Haram | PENDING |  | <!--cell:E920::animal::zabiha-->
|  | E920 | animal | Hanafi-strict | JAKIM / MUI / ESMA | 5 — Haram | PENDING |  | <!--cell:E920::animal::hanafiStrict-->
|  | E920 | animal | General Halal | IFANCA / ISNA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E920::animal::general-->
|  | E920 | animal | Lenient | most permissive published scholarly position (needs 2 sources) | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E920::animal::lenient-->
|  | E920 | synthetic | Zabiha-only | HMC / HFSAA | 2 — Questionable — widely accepted | PENDING |  | <!--cell:E920::synthetic::zabiha-->
|  | E920 | synthetic | Hanafi-strict | JAKIM / MUI / ESMA | 1 — Halal | PENDING |  | <!--cell:E920::synthetic::hanafiStrict-->
|  | E920 | synthetic | General Halal | IFANCA / ISNA | 1 — Halal | PENDING |  | <!--cell:E920::synthetic::general-->
|  | E920 | synthetic | Lenient | most permissive published scholarly position (needs 2 sources) | 1 — Halal | PENDING |  | <!--cell:E920::synthetic::lenient-->
|  | E920 | unspecified | Zabiha-only | HMC / HFSAA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E920::unspecified::zabiha-->
|  | E920 | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 4 — Questionable — widely avoided | PENDING |  | <!--cell:E920::unspecified::hanafiStrict-->
|  | E920 | unspecified | General Halal | IFANCA / ISNA | 3 — Questionable — contested | PENDING |  | <!--cell:E920::unspecified::general-->
|  | E920 | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 3 — Questionable — contested | PENDING |  | <!--cell:E920::unspecified::lenient-->
|  | vitamin d3 | unspecified | Zabiha-only | HMC / HFSAA | 2 — Questionable — widely accepted | PENDING |  | <!--cell:vitamin d3::unspecified::zabiha-->
|  | vitamin d3 | unspecified | Hanafi-strict | JAKIM / MUI / ESMA | 2 — Questionable — widely accepted | PENDING |  | <!--cell:vitamin d3::unspecified::hanafiStrict-->
|  | vitamin d3 | unspecified | General Halal | IFANCA / ISNA | 2 — Questionable — widely accepted | PENDING |  | <!--cell:vitamin d3::unspecified::general-->
|  | vitamin d3 | unspecified | Lenient | most permissive published scholarly position (needs 2 sources) | 2 — Questionable — widely accepted | PENDING |  | <!--cell:vitamin d3::unspecified::lenient-->

> The porcine / khamr **hard-haram pin** (Haram, every position) is enforced
> in `GradeMatrix.cell(for:)`, not a contestable cell — but still cite the
> prohibition (e.g. Qur'an 2:173 / 5:3) and confirm the pin's token list.

---


## 2. Certifier → standard satisfaction (pending data — research + cite)

Each pairing is pending until cited to the body's OWN published criteria.
**Open question: should any differ for meat vs non-meat products?**

| Body | Position | Governing for | Satisfies? (draft) | Source name / reference / date / tier |
|---|---|---|---|---|
| IFANCA | Zabiha-only | HMC / HFSAA | no |  | <!--cert:ifanca::zabiha-->
| IFANCA | Hanafi-strict | JAKIM / MUI / ESMA | no |  | <!--cert:ifanca::hanafiStrict-->
| IFANCA | General Halal | IFANCA / ISNA | yes |  | <!--cert:ifanca::general-->
| IFANCA | Lenient | most permissive published scholarly position (needs 2 sources) | yes |  | <!--cert:ifanca::lenient-->
| ISNA | Zabiha-only | HMC / HFSAA | no |  | <!--cert:isna::zabiha-->
| ISNA | Hanafi-strict | JAKIM / MUI / ESMA | no |  | <!--cert:isna::hanafiStrict-->
| ISNA | General Halal | IFANCA / ISNA | yes |  | <!--cert:isna::general-->
| ISNA | Lenient | most permissive published scholarly position (needs 2 sources) | yes |  | <!--cert:isna::lenient-->
| HFSAA | Zabiha-only | HMC / HFSAA | yes |  | <!--cert:hfsaa::zabiha-->
| HFSAA | Hanafi-strict | JAKIM / MUI / ESMA | yes |  | <!--cert:hfsaa::hanafiStrict-->
| HFSAA | General Halal | IFANCA / ISNA | yes |  | <!--cert:hfsaa::general-->
| HFSAA | Lenient | most permissive published scholarly position (needs 2 sources) | yes |  | <!--cert:hfsaa::lenient-->
| HMC | Zabiha-only | HMC / HFSAA | yes |  | <!--cert:hmc::zabiha-->
| HMC | Hanafi-strict | JAKIM / MUI / ESMA | yes |  | <!--cert:hmc::hanafiStrict-->
| HMC | General Halal | IFANCA / ISNA | yes |  | <!--cert:hmc::general-->
| HMC | Lenient | most permissive published scholarly position (needs 2 sources) | yes |  | <!--cert:hmc::lenient-->
| JAKIM | Zabiha-only | HMC / HFSAA | no |  | <!--cert:jakim::zabiha-->
| JAKIM | Hanafi-strict | JAKIM / MUI / ESMA | yes |  | <!--cert:jakim::hanafiStrict-->
| JAKIM | General Halal | IFANCA / ISNA | yes |  | <!--cert:jakim::general-->
| JAKIM | Lenient | most permissive published scholarly position (needs 2 sources) | yes |  | <!--cert:jakim::lenient-->
| MUI | Zabiha-only | HMC / HFSAA | no |  | <!--cert:mui::zabiha-->
| MUI | Hanafi-strict | JAKIM / MUI / ESMA | yes |  | <!--cert:mui::hanafiStrict-->
| MUI | General Halal | IFANCA / ISNA | yes |  | <!--cert:mui::general-->
| MUI | Lenient | most permissive published scholarly position (needs 2 sources) | yes |  | <!--cert:mui::lenient-->
| ESMA | Zabiha-only | HMC / HFSAA | no |  | <!--cert:esma::zabiha-->
| ESMA | Hanafi-strict | JAKIM / MUI / ESMA | yes |  | <!--cert:esma::hanafiStrict-->
| ESMA | General Halal | IFANCA / ISNA | yes |  | <!--cert:esma::general-->
| ESMA | Lenient | most permissive published scholarly position (needs 2 sources) | yes |  | <!--cert:esma::lenient-->

---


## 3. Contested & cross-position appendix

Cross-position differences are the positions doing their job (not
"contested"). A cell is **contested** only when sources split *within one
position* — then it stores BOTH citations. Below: rows where the four
positions diverge, with how many citations are on file.

| Subject | Origin | Zabiha | Hanafi-strict | General | Lenient | Source | Citations on file |
|---|---|---|---|---|---|---|---|
| flavor ethanol carrier | unspecified | 4 | 4 | 2 | 1 | Spec §1: flavor ethanol carrier, final <0.5%, non-khamr | 0 |
| E120 | unspecified | 4 | 4 | 4 | 2 | Spec §1: carmine / cochineal (E120) | 0 |
| alcohol | unspecified | 4 | 4 | 3 | 2 | Spec §1: alcohol carrier (non-khamr) — vanilla-extract tier | 0 |
| enzyme | animal | 5 | 4 | 3 | 3 | Spec §1: animal rennet, calf, unverified | 0 |
| enzyme | unspecified | 5 | 4 | 3 | 3 | Spec §1: animal rennet, unverified (unspec) | 0 |
| vanilla extract | unspecified | 4 | 4 | 3 | 2 | Spec §1: vanilla extract (≥35% ethanol, non-khamr) | 0 |
| E153 | unspecified | 4 | 3 | 3 | 3 | Spec §1: vegetable/bone carbon (E153) | 0 |
| E422 | unspecified | 4 | 4 | 3 | 3 | Spec §1: glycerin / glycerol (E422) | 0 |
| E470 | unspecified | 4 | 3 | 3 | 3 | Spec §1: magnesium stearate / stearic acid (E470b) | 0 |
| E471 | unspecified | 4 | 4 | 3 | 3 | Spec §1: mono/diglycerides (E471) | 0 |
| E472 | unspecified | 4 | 4 | 3 | 3 | Spec §1: esters (E472, DATEM) | 0 |
| E542 | unspecified | 5 | 4 | 4 | 4 | Spec §1: bone phosphate (E542) | 0 |
| E570 | unspecified | 4 | 3 | 3 | 3 | Spec §1: stearic acid (E570) | 0 |
| E627 | unspecified | 4 | 3 | 3 | 3 | Spec §1: disodium guanylate (E627) | 0 |
| E631 | unspecified | 4 | 3 | 3 | 3 | Spec §1: disodium inosinate (E631) | 0 |
| E920 | unspecified | 4 | 4 | 3 | 3 | Spec §1: L-cysteine (E920) unspecified | 0 |
| E920 | animal | 5 | 5 | 4 | 4 | Spec §1: L-cysteine human-hair/animal source | 0 |
| E920 | synthetic | 2 | 1 | 1 | 1 | Spec §1: L-cysteine synthetic/fermentation | 0 |
| gelatin | animalNonZabiha | 5 | 4 | 4 | 4 | Spec §1: gelatin bovine non-zabiha | 0 |
| gelatin | unspecified | 5 | 4 | 4 | 4 | Spec §1: gelatin unspecified → non-zabiha default | 0 |
| meat | animalNonZabiha | 5 | 4 | 4 | 4 | Spec §1: non-zabiha land-animal derivative | 0 |
| meat | unspecified | 5 | 4 | 4 | 4 | Spec §1: non-zabiha land-animal derivative (unspec) | 0 |
| whey | unspecified | 4 | 3 | 3 | 3 | Spec §1: whey, rennet source unknown | 0 |

Grades: 1 Halal · 2 Questionable-widely-accepted · 3 Questionable-contested · 4 Questionable-widely-avoided · 5 Haram.

---


## 4. Researcher sourcing log

Who did the sourcing, when, and against which corpora — so the trail is
auditable and a scholar can later verify or extend it.

- **Researcher:** _______________________________________
- **Date(s) of research:** ______________________________
- **Sources consulted** (standards bodies' docs, journals/Google Scholar): __________________________
- **Field-validation scans logged** (gtin · product · position · grade · looked right?): ____________
- **Items cleared this pass** (subject · origin · position): ______________________________________
- **Items still pending** (left uncited on purpose): _____________________________________________

---

_Generated from code by `ReviewDocument.generate()`. `ReviewDocumentTests`
asserts it covers every seeded cell and enforces the §8 gate (no clearance
without a tier-1/2 well-formed citation; two independent for high-traffic /
lenient; origin-undeterminable never halal). Citations live in
`Citations.json` — don't hand-edit grades here._

**Sourced from published halal standards and scholarly references — verify with a scholar you trust for your situation.**
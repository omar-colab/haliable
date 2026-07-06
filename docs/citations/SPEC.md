# Citation Pipeline — Spec

_Status: v1, 2026-06-27. The agentic system that fills `Citations.json` with real
scholarly sources so seeded grade cells and certifier claims clear the §8 gate.
You (the owner) are the approval gate; nothing clears without a real, approved source._

---

## 1. The reframe that makes this tractable

The app grades **ingredients**, not products. `GradeMatrix` seeds ~per-ingredient
cells keyed `{subject, origin, position}` (gelatin, E471, natural flavors, E120,
whey, alcohol carriers, …) plus `CertificationBody → HalalStandard` satisfaction
claims. Cite each cell **once** and that sourced verdict applies across the
**millions** of Open Food Facts + USDA products the scanner already resolves. The
small worklist is **leverage, not a limit**.

Today every cell is `needsReview` and `Citations.json` ships empty by design.

## 2. The one real fork — reuse the app's engine, don't reimplement it

The clearance rules already live in Swift and are enforced in code:

- `GradeCell.isCleared` (`Models/GradeCell.swift`) — §8 gate for grade cells:
  ≥1 tier-1/2 **well-formed** citation; **≥2 independent** if `isHighTraffic` or
  `position == .lenient`; an origin-undeterminable cell may never clear to `halal`.
- `SatisfactionClaim.isClearedSatisfaction` (`Models/SatisfactionClaim.swift`) —
  a positive certifier claim clears with ≥1 tier-1/2 well-formed citation.
- `Citation.clears` / `isWellFormed` (`Models/Citation.swift`) — per-source strength.

**Decision:** the pipeline **validates candidate citations by running them through
these exact types** — never a parallel Python re-implementation of the rules. The
pipeline therefore *cannot* clear a cell the app itself wouldn't. Tooling is Swift,
test-driven, mirroring the existing `ReviewDocument` / `GradeMatrix+Review`
generators (and their coverage tests). Rejected: a standalone script that would
duplicate the rules and drift.

## 3. The five components

### 1 — Backlog enumerator (`Services/Citations/CitationBacklog.swift`) — built
Walks the live `GradeMatrix.allSeededEntries` (cells) + the **positive**
`SatisfactionClaim`s (certifier claims that draft-satisfy) and emits the complete
worklist: every item keyed exactly as `CitationStore` keys it, with draft grade,
governing body, `isHighTraffic`, **sourcesNeeded (1 or 2)**, current status, and a
`blocked` flag for cells that can never clear as-is (origin-undeterminable +
draft-halal — these need an origin signal, not a citation). Outputs
`docs/citations/backlog.json` + a readable `backlog.md` index.
A **coverage test** asserts the backlog's keys exactly equal what the engine
grades on, so it can never drift from the matrix.

### 2 — Candidate staging (`docs/citations/candidates/*.json`)
Per cell, the research (web) produces a structured `CitationCandidate` record:
target key + proposed `[Citation]` (sourceName / reference / date / tier /
paraphrase) + researcher confidence + flags + a `decision` field. This is the
agentic marathon, done in batches over many sessions. **No fabrication** — a cell
with no real tier-1/2 source stays pending.

### 3 — Your approval gate
Each session the staged candidates are presented in a tight, readable form. You
mark **approve / reject / needs-better-source**. Only `approved` candidates proceed.
This is a human step, not code.

### 4 — Validator + committer (`Services/Citations/CitationCommitter.swift`) — built
Takes approved candidates, **validates each against the real gate** (constructs the
live cell / claim with the proposed citations and checks `isCleared` /
`isClearedSatisfaction`), and writes the passing ones into `Citations.json` at the
correct key. Idempotent (keyed merge), reversible (it's just JSON under git).
A test proves a committed cell actually flips `needsReview → cited` **in the live
engine** (by swapping `CitationStore.shared`), and that a single-source or tier-3
candidate for a high-traffic cell is **rejected**.

### 5 — Progress ledger (`Services/Citations/CitationLedger.swift` → `progress.md`) — built
Cleared vs. remaining, high-traffic breakdown, priority order — regenerated each
session so we resume cleanly day to day.

## 4. Priority order

High-traffic subjects first (they unlock the most real scans):
`gelatin · E471 · natural flavors · E120 · whey · E322 · E422 · alcohol /
vanilla-extract carriers · enzyme`. The backlog and ledger both sort these first.

## 5. How we work, day to day

- **Week 1 (now):** build components 1, 4, 5 (safe tooling) + a proven 2-cell
  vertical slice end-to-end so the full research → approve → commit → flip loop is
  demonstrated in tests (with clearly test-only citations; shipping `Citations.json`
  stays empty until you approve real sources).
- **Every session after:** research a batch → stage candidates → you approve →
  commit → ledger updates. Repeat until the backlog is green.

**Reality check:** the tooling is near-term; the research is the long pole — each
of ~130 cells/claims needs genuine tier-1/2 sourcing (JAKIM, MUI, AMJA, IFANCA,
HMC, peer-reviewed work). That is weeks of work, exactly as expected.

## 6. Invariants this pipeline must never break

1. **No fabrication.** Only real, checkable sources; you approve each.
2. **One gate.** Validation goes through the app's own `isCleared` /
   `isClearedSatisfaction` — never a copy.
3. **Data, not code.** Clearing a cell only ever edits `Citations.json`; no Swift
   change can clear a cell.
4. **Fail safe.** Unproven cells stay visibly pending at their conservative grade.
5. **Green + guarded.** The test suite stays green and `NoTodoGuard` intact.

# Review-agent protocol

A user photographs a label the scanner can't resolve and asks for a human ruling.
That request lands in `review_requests`. This protocol says how it gets answered.

**The agent researches. Omar decides. Nothing reaches a user unapproved.**

That is not ceremony. `CLAUDE.md` rule 3 is "report, don't rule" — the app reports
what scholars published, it does not form opinions. An agent that answered users
directly would be the app issuing rulings in its own voice, which is the one thing
this product must never do.

## Source tiers

Taken from `SourceTier` in `Haliable/Models/Citation.swift` — not invented here, so
the agent and the app grade evidence identically.

| Tier | What counts | Can it clear a cell? |
|---|---|---|
| 1 | The standard body's **own published document** — JAKIM MS1500, MUI fatwa, ESMA, SMIIC, IFANCA, HMC, HFSAA | **Yes** |
| 2 | **Peer-reviewed** scholarship — journal article, Google Scholar | **Yes** |
| 3 | Reputable explainer, fatwa aggregator, encyclopaedia | **No** — orientation only |

A Tier 3 source may shape the reasoning and may be cited *alongside* a Tier 1/2
source. It can never be the sole basis of a verdict.

## What the agent must produce per ingredient

Every one of these, or the ingredient is `unresolved`:

- `sourceName` — the body and document, e.g. `JAKIM MS1500:2019`, not "a fatwa site"
- `reference` — a URL, or document plus clause/page. Must resolve.
- `date` — publication date, or access date for a live page
- `tier` — 1, 2 or 3
- `paraphrase` — what the source actually says, in enough detail that a reader can
  check the verdict against it without following the link

## Hard rules the validator enforces

1. **No invented sources.** Every `reference` is fetched and must return 200 and
   contain the paraphrase's key terms. A reference that cannot be fetched is
   rejected, not downgraded.
2. **Worst-case rollup** (rule 4). The product's verdict is the worst grade among
   its ingredients. Never an average, never a best case.
3. **Unresolved is not halal.** If any ingredient lacks a Tier 1/2 source, the
   product cannot be returned as `halal`. It returns `doubtful` with the unresolved
   ingredient named. Silence is never read as permission.
4. **Disagreement is reported, not resolved.** Where bodies differ, both positions
   are cited and the verdict follows the stricter one. The agent does not decide
   which scholar is right.
5. **Origin matters.** Gelatin, enzymes, mono- and diglycerides, whey and L-cysteine
   all depend on source material. Unspecified origin is unresolved, not halal.
6. **The agent never writes to the database.** It writes a draft file. Only
   `push` — run by Omar, after approval — touches `review_requests`.

## The loop

```
pull     → fetch pending requests, write one brief per request
           (brief carries the ingredients, what Citations.json already has,
            and exactly which cells are missing evidence)

research → the agent fills the brief: a source block per unresolved ingredient
           (this is the step a model does; everything else is deterministic)

stage    → validate. Every rule above is checked mechanically.
           Failures are listed; nothing is staged until they are fixed.

review   → Omar reads the draft reply and the evidence. approve / reject /
           needs-better-source. Mirrors CandidateDecision in the existing pipeline.

push     → approved drafts are written back: status=completed, verdict,
           verdict_reason, evidence. The user sees it on next refresh.
```

## It also improves the app, not just the one answer

A review request is the only moment where a real person is waiting on a gap in
`Citations.json`. When research clears an ingredient, `stage` also emits a
`CitationCandidate` in the format the existing pipeline already reads
(`Haliable/Services/Citations/CitationCandidate.swift`), so Omar's approval can
feed the matrix and every future scan of that ingredient benefits.

Citations.json is still never hand-edited — rule 2. The committer does it.

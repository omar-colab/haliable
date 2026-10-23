//
//  MatchedIngredient.swift
//  Haliable
//
//  Created by Omar O on 5/26/26.
//

import Foundation

// The result of checking ONE ingredient from a scanned product.
struct MatchedIngredient: Identifiable, Hashable {
    let id = UUID()
    let originalText: String          // what appeared on the label
    let matchedRule: IngredientRule?  // the rule we found — or nil if unknown

    /// The user's active strictness position, applied to this ingredient's
    /// baseline verdict. Defaults to the mainstream baseline so existing callers
    /// (tests, previews) keep the original behavior unless a standard is passed.
    var standard: HalalStandard = .general

    /// Phase 1 (grading refactor): the working assumption about this ingredient's
    /// source. Defaults to `.unspecified` (the common scanned-label case). Phase 2
    /// uses this — with category + standard — to pick the GradeMatrix cell.
    var originAssumption: Origin = .unspecified

    /// Why an ingredient with no rule was flagged, in plain words ("Contains
    /// chicken; the label doesn't say how it was slaughtered"). Display only.
    var note: String? = nil

    /// The label text this was found in, exactly as the parser read it. Display only.
    var labelText: String? = nil

    /// Position on the label (lower = earlier). Breaks ties between equal grades
    /// so the reported driver is the same on every run.
    var labelIndex: Int = Int.max

    /// Category for an ingredient with no rule, set by the engine's signal table
    /// (meat, collagen). Grading falls back to keyword classification without it.
    var categoryHint: IngredientCategory? = nil

    /// The baseline verdict before the standard is applied.
    /// An unknown ingredient is NEVER assumed halal — it falls to Questionable
    /// (`.doubtful`) so the worst-case roll-up can surface it to the user.
    var baseVerdict: Verdict {
        matchedRule?.verdict ?? .doubtful
    }

    /// The 5-level grade for this ingredient under the active standard, plus its
    /// provenance — sourced from the seeded GradeMatrix (Phase 2 cutover). Hard-
    /// haram substances (porcine, khamr) are pinned to Haram regardless of
    /// standard; subjects the spec table doesn't cover defer to the rule baseline.
    var gradeCell: GradeCell {
        GradeMatrix.cell(for: self)
    }

    /// The 5-level grade.
    var grade: GradeLevel { gradeCell.grade }

    /// The 3-value ruling the rest of the app consumes — now DERIVED from the
    /// 5-level grade via `coarse`. This replaces the retired `adjustedVerdict`.
    var verdict: Verdict { grade.coarse }

    /// True until the underlying cell is backed by a valid published citation.
    /// The verdict UI shows a "pending review" treatment while this holds.
    var needsReview: Bool { gradeCell.needsReview }

    /// Published sources backing this ingredient's reported position (Spec §B).
    var citations: [Citation] { gradeCell.citations }

    /// A genuinely contested cell: a contested grade carrying ≥2 citations. The
    /// verdict UI renders both positions for these (Spec §A2).
    var isContested: Bool { gradeCell.isContested }

    /// The human-facing ingredient name.
    var displayName: String {
        matchedRule?.ingredient ?? originalText
    }

    /// A written explanation that always accompanies the verdict — this is the
    /// "show your work" promise. Known ingredients use the rule's cited reason;
    /// unknown ones get an honest "we couldn't source this" note.
    var explanation: String {
        matchedRule?.reason ?? note
            ?? "This ingredient isn't in our verified database and its source couldn't be confirmed, so it's marked Questionable until you can verify it on the label or with the manufacturer."
    }

    /// The source the grade was worked out for ("Plant", "Source not disclosed").
    var resolvedOrigin: Origin { GradeMatrix.resolveOrigin(for: self) }

    /// The citation behind a known verdict, if any.
    var source: Source? {
        matchedRule?.source
    }
}

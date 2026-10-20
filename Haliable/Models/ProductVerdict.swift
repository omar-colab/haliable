//
//  ProductVerdict.swift
//  Haliable
//
//  Created by Omar O on 5/26/26.
//

import Foundation

// The full result for an entire scanned product.
struct ProductVerdict: Identifiable, Hashable {
    let id = UUID()
    let product: Product
    let matched: [MatchedIngredient]

    /// The 5-level roll-up — worst grade among matched ingredients, AFTER the
    /// certification overlay (computed in RulesEngine.evaluate). The UI reads this.
    let overallGrade: GradeLevel

    /// The 3-value ruling for persistence and existing call sites, derived from
    /// the 5-level grade.
    var overall: Verdict { overallGrade.coarse }

    /// Only the ingredients that are a concern (haram or Questionable),
    /// worst first. This is what the verdict screen surfaces.
    var flagged: [MatchedIngredient] {
        matched
            .filter { $0.verdict != .halal }
            .sorted { $0.verdict.severity > $1.verdict.severity }
    }

    /// 0–100: share of checked ingredients that cleared (100 when nothing
    /// questionable matched). Shown in History's ring. It never replaces the
    /// worst-case verdict — the ring is tinted by that verdict.
    var clearedScore: Int {
        guard !matched.isEmpty else { return 100 }
        return Int((Double(matched.count - flagged.count) / Double(matched.count) * 100).rounded())
    }

    /// True when the grade driving the headline verdict is still a DRAFT cell
    /// (`needsReview`). Phase 4: the verdict screen reads this to swap the
    /// confident badge for an unmistakable "pending scholar review" treatment so
    /// no flagged-and-draft cell presents as an authoritative ruling. Keyed on
    /// the flagged set (the cells the screen actually surfaces); a clean,
    /// nothing-flagged product keeps its confident verdict.
    var overallNeedsReview: Bool {
        flagged.contains { $0.needsReview }
    }

    /// A one-line, honest summary of why the product got its verdict.
    var summary: String {
        switch overall {
        case .haram:
            return "Contains one or more ingredients that are not permissible."
        case .doubtful:
            return "Some ingredients couldn't be confirmed halal. See the explanations below before deciding."
        case .halal:
            return "No prohibited or questionable ingredients were detected against our verified rules."
        }
    }
}

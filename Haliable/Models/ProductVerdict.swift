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
    /// worst first. This is what the verdict screen surfaces. Ties keep label
    /// order, so the first row (the "driver") is the same on every run.
    var flagged: [MatchedIngredient] {
        matched.enumerated()
            .filter { $0.element.verdict != .halal }
            .sorted { a, b in
                if a.element.grade != b.element.grade { return a.element.grade > b.element.grade }
                if a.element.labelIndex != b.element.labelIndex { return a.element.labelIndex < b.element.labelIndex }
                return a.offset < b.offset
            }
            .map(\.element)
    }

    /// 0–100: share of the label's ingredients that are NOT flagged. Shown in
    /// History's ring. A haram product scores 0 — one haram ingredient in twenty
    /// is not "95% fine" (worst-case stance, Omar 2026-10-21).
    var clearedScore: Int {
        let total = max(Self.ingredientCount(product.rawIngredientsText ?? ""), matched.count)
        // Worst case: one haram ingredient makes the whole product 0, not 95.
        if overallGrade == .haram { return 0 }
        guard total > 0 else { return 100 }
        return Int((Double(total - flagged.count) / Double(total) * 100).rounded())
    }

    /// Top-level comma/semicolon items: "sugar, gelatin (beef, pork), salt" is 3.
    static func ingredientCount(_ text: String) -> Int { ingredientItems(text).count }

    /// The label's top-level items in order, sub-ingredients kept in their brackets:
    /// "sugar, gelatin (beef, pork), salt." → ["sugar", "gelatin (beef, pork)", "salt"].
    static func ingredientItems(_ text: String) -> [String] {
        var depth = 0, items: [String] = [], current = ""
        func flush() {
            let item = current.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
            if !item.isEmpty { items.append(item) }
            current = ""
        }
        for ch in text {
            switch ch {
            case "(", "[": depth += 1
            case ")", "]": depth = max(0, depth - 1)
            case "," where depth == 0, ";" where depth == 0:
                flush()
                continue
            default: break
            }
            current.append(ch)
        }
        flush()
        return items
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

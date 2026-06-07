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
    let overall: Verdict

    /// Only the ingredients that are a concern (haram or Questionable),
    /// worst first. This is what the verdict screen surfaces.
    var flagged: [MatchedIngredient] {
        matched
            .filter { $0.verdict != .halal }
            .sorted { $0.verdict.severity > $1.verdict.severity }
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

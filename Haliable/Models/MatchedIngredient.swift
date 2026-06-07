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

    /// The verdict for this single ingredient.
    /// An unknown ingredient is NEVER assumed halal — it falls to Questionable
    /// (`.doubtful`) so the worst-case roll-up can surface it to the user.
    var verdict: Verdict {
        matchedRule?.verdict ?? .doubtful
    }

    /// The human-facing ingredient name.
    var displayName: String {
        matchedRule?.ingredient ?? originalText
    }

    /// A written explanation that always accompanies the verdict — this is the
    /// "show your work" promise. Known ingredients use the rule's cited reason;
    /// unknown ones get an honest "we couldn't source this" note.
    var explanation: String {
        matchedRule?.reason
            ?? "This ingredient isn't in our verified database and its source couldn't be confirmed, so it's marked Questionable until you can verify it on the label or with the manufacturer."
    }

    /// The citation behind a known verdict, if any.
    var source: Source? {
        matchedRule?.source
    }
}

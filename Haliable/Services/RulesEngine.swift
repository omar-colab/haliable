//
//  RulesEngine.swift
//  Haliable
//
//  Created by Omar O on 5/30/26.
//

import Foundation
import Observation

// RulesEngine is the brain that decides: given a scanned product,
// which ingredients are flagged, and what's the overall verdict?
//
// Design principle (carried from the dossier): a false "Halal" is the
// unforgivable error. So anything we cannot positively confirm — unknown
// E-numbers, undisclosed sources, or a product with NO ingredient data —
// falls to "Questionable" (.doubtful), never silently to halal.
@Observable
final class RulesEngine {

    private(set) var rules: [IngredientRule] = []
    private(set) var eNumberMap: [String: String] = [:]

    // Fast lookup tables built ONCE when rules load.
    private var aliasIndex: [String: IngredientRule] = [:]
    private var eNumIndex: [String: IngredientRule] = [:]

    init() {
        do {
            rules = try RulesLoader.loadRules()
            eNumberMap = try RulesLoader.loadENumbers()
            buildIndex()
        } catch {
            print("RulesEngine load failed: \(error)")
        }
    }

    private func buildIndex() {
        for rule in rules {
            aliasIndex[rule.ingredient.lowercased()] = rule
            for alias in rule.aliases {
                aliasIndex[alias.lowercased()] = rule
            }
            if let eNumber = rule.eNumber?.uppercased() {
                eNumIndex[eNumber] = rule
            }
        }
    }

    // The main function: given a Product, return a full ProductVerdict.
    func evaluate(product: Product) -> ProductVerdict {
        var matched: [MatchedIngredient] = []

        // STEP 1: structured E-number list from Open Food Facts (most reliable).
        for eNumber in product.additivesENumbers {
            let canonicalName = eNumberMap[eNumber] ?? eNumber
            let rule = eNumIndex[eNumber] ?? aliasIndex[canonicalName.lowercased()]
            // An E-number we don't recognize stays as a nil-rule match → Questionable.
            matched.append(MatchedIngredient(
                originalText: rule?.ingredient ?? "\(eNumber) (\(canonicalName))",
                matchedRule: rule
            ))
        }

        // STEP 2: free-text scan of the ingredients string.
        let ingredientsText = (product.rawIngredientsText ?? "").lowercased()
        for (alias, rule) in aliasIndex where ingredientsText.contains(alias) {
            let alreadyMatched = matched.contains { $0.matchedRule?.id == rule.id }
            if !alreadyMatched {
                matched.append(MatchedIngredient(
                    originalText: alias,
                    matchedRule: rule
                ))
            }
        }

        // STEP 3: SAFETY NET — if we had nothing to inspect, we cannot claim halal.
        let hasIngredientData =
            !ingredientsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !product.additivesENumbers.isEmpty
        if !hasIngredientData {
            matched.append(MatchedIngredient(
                originalText: "No ingredient information available",
                matchedRule: nil   // nil rule → Questionable, with an explanation
            ))
        }

        // STEP 4: roll up to one overall verdict using worst-case logic.
        // haram > Questionable(doubtful) > halal.
        let overall = matched
            .map(\.verdict)
            .max(by: { $0.severity < $1.severity }) ?? .halal

        return ProductVerdict(product: product, matched: matched, overall: overall)
    }
}

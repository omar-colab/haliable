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
    //
    // `standard` is the user's active strictness position. It rides along on every
    // MatchedIngredient so the per-ingredient verdict AND the roll-up reflect it
    // (e.g. Zabiha escalates unconfirmed meat to Haram). Defaults to the mainstream
    // baseline so existing callers and the unit tests are unaffected.
    func evaluate(product: Product, standard: HalalStandard = .general) -> ProductVerdict {
        var matched: [MatchedIngredient] = []
        let ingredientsText = (product.rawIngredientsText ?? "").lowercased()

        // STEP 1: structured E-number list from Open Food Facts (most reliable).
        // Origin is read from the label segment that names the additive, so an
        // E-number paired with "soy lecithin" on the label resolves to plant.
        for eNumber in product.additivesENumbers {
            let canonicalName = eNumberMap[eNumber] ?? eNumber
            let rule = eNumIndex[eNumber] ?? aliasIndex[canonicalName.lowercased()]
            // An E-number we don't recognize stays as a nil-rule match → Questionable.
            matched.append(MatchedIngredient(
                originalText: rule?.ingredient ?? "\(eNumber) (\(canonicalName))",
                matchedRule: rule,
                standard: standard,
                originAssumption: inferOrigin(forTerm: canonicalName.lowercased(), in: ingredientsText)
            ))
        }

        // STEP 2: free-text scan of the ingredients string. The matched term's
        // whole list-segment is captured, so an origin qualifier ANYWHERE in it
        // ("soy lecithin", "lecithin (soya)", "lecithin from soybeans") resolves —
        // not just a single adjacent word.
        for (alias, rule) in aliasIndex where ingredientsText.contains(alias) {
            let alreadyMatched = matched.contains { $0.matchedRule?.id == rule.id }
            if !alreadyMatched {
                let seg = segment(containing: alias, in: ingredientsText) ?? alias
                matched.append(MatchedIngredient(
                    originalText: seg,
                    matchedRule: rule,
                    standard: standard,
                    originAssumption: ENumberReference.inferOrigin(from: seg) ?? .unspecified
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
                matchedRule: nil,   // nil rule → Questionable, with an explanation
                standard: standard
            ))
        }

        // STEP 4: roll up to one overall GRADE using worst-case logic, then apply
        // the certification overlay.
        let worstGrade = matched.map(\.grade).max() ?? .halal

        // Certification overlay: when a certifier whose satisfaction of the active
        // standard is CITED is on the label, it has vetted the ingredients — so
        // upgrade a NON-haram product to Halal. Gated by the SAME citation rule as
        // the badge (Citation Protocol §8): an uncited satisfaction claim can't
        // produce a confident "Halal" in the app's own voice. It never upgrades
        // past a haram ingredient — a "halal" claim over pork/khamr is contradictory.
        let overallGrade: GradeLevel
        if worstGrade < .haram,
           let body = CertificationBody.detect(in: product.labels),
           SatisfactionClaim.make(body: body, standard: standard).isClearedSatisfaction {
            overallGrade = .halal
        } else {
            overallGrade = worstGrade
        }

        return ProductVerdict(product: product, matched: matched, overallGrade: overallGrade)
    }

    /// The comma/semicolon/newline-delimited list-segment that mentions `term`.
    /// Parentheses are intentionally NOT split on, so "lecithin (soya)" stays one
    /// segment. Trimmed of surrounding whitespace.
    private func segment(containing term: String, in text: String) -> String? {
        let separators = CharacterSet(charactersIn: ",;\n•")
        return text.components(separatedBy: separators)
            .first { $0.contains(term) }?
            .trimmingCharacters(in: .whitespaces)
    }

    /// Infer an origin for `term` from the label segment that names it — catching
    /// qualifiers before OR after the term. `.unspecified` when none is disclosed.
    private func inferOrigin(forTerm term: String, in text: String) -> Origin {
        guard let seg = segment(containing: term, in: text) else { return .unspecified }
        return ENumberReference.inferOrigin(from: seg) ?? .unspecified
    }
}

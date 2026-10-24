//
//  HalalStandard.swift
//  Haliable
//
//  The user's chosen STRICTNESS POSITION — how cautious Haliable should be when
//  rolling up a verdict. This is distinct from a certification *body* (IFANCA,
//  HMC, …): a body is an organization; a standard is a fiqh position the engine
//  enforces. One `HalalStandard` is the single source of truth, set from either
//  the Scanner pill or the Settings picker (see AppSettings.halalStandard).
//
//  SAFETY NOTE (carried from the dossier): a false "Halal" is the unforgivable
//  error. So the per-standard transform only ever ESCALATES caution for the
//  strict standards (doubtful → haram). The single de-escalation (lenient
//  softening) is tightly bounded and NEVER touches a hard-haram substance.
//
//  ⚠️ FIQH ACCURACY: the strictness transforms and certifier mappings below are
//  a first pass. Uncertainty is not a code comment — it is a DATA STATE: every
//  mapping here is PENDING until backed by a published citation in Citations.json,
//  at which point the clearance gate (GradeCell §8) flips it. Nothing here is
//  presented to users as authoritative while uncited.
//

import SwiftUI

// MARK: - HalalStandard

enum HalalStandard: String, CaseIterable, Identifiable, Codable {
    case zabiha        // strictest
    case hanafiStrict
    case general       // mainstream baseline — the default
    case lenient       // Ahl al-Kitab leaning

    /// The default used until the user chooses, and for "decide later".
    static let fallback: HalalStandard = .general

    var id: String { rawValue }

    /// Higher = stricter. Used for ordering the list (strict → lenient) and for
    /// the certifier "meets your standard?" comparison.
    var strictnessRank: Int {
        switch self {
        case .zabiha:       return 3
        case .hanafiStrict: return 2
        case .general:      return 1
        case .lenient:      return 0
        }
    }

    var displayName: String {
        switch self {
        case .zabiha:       return "Zabiha-only"
        case .hanafiStrict: return "Hanafi-strict"
        case .general:      return "General Halal"
        case .lenient:      return "Lenient"
        }
    }

    /// One-line, shown on the card and (with the body) in the sheet.
    var shortDescription: String {
        switch self {
        case .zabiha:       return "Hand-slaughtered only. Strictest on meat, gelatin & enzymes."
        case .hanafiStrict: return "Flags alcohol traces & doubtful additives. Fish-only seafood."
        case .general:      return "Mainstream certifier baseline. Machine slaughter accepted."
        case .lenient:      return "People-of-the-Book meat accepted. Softer on doubtful additives."
        }
    }

    var symbol: String {
        switch self {
        case .zabiha:       return "hand.raised.fill"
        case .hanafiStrict: return "exclamationmark.shield.fill"
        case .general:      return "checkmark.shield.fill"
        case .lenient:      return "leaf.fill"
        }
    }

    /// The expandable "what this means" explanation — plain language, no jargon
    /// dumps. Also reused by the education screen.
    var whatThisMeans: String {
        switch self {
        case .zabiha:
            return "You only accept meat from animals slaughtered by hand with the name of Allah said over each one. We treat any meat, gelatin, or animal-derived enzyme whose source we can't confirm as Haram rather than Questionable — better to send you to check than to risk it."
        case .hanafiStrict:
            return "A cautious position common in the Hanafi school: even trace alcohol from flavorings or processing, and additives (E-numbers) whose source we can't confirm, are flagged as Haram. Among sea creatures, only fish are considered permissible — shellfish and other seafood are flagged."
        case .general:
            return "The mainstream baseline that most halal certifiers use. Machine slaughter under Islamic conditions is accepted. Ingredients we can't confirm are marked Questionable so you can decide, and clearly prohibited ingredients are Haram."
        case .lenient:
            return "Reflects the view that meat of the People of the Book (Jews and Christians) is permissible. Doubtful additives are kept as Questionable rather than escalated to Haram. Clearly prohibited substances — pork, intoxicating alcohol, blood — are ALWAYS Haram regardless of this setting."
        }
    }
}

// MARK: - Ingredient classification (heuristic)

/// A coarse category used by a standard to decide how to treat an ingredient.
///
/// PRIMARY source is the explicit `category` tag on the matched IngredientRule
/// (see rules-v1.json). The keyword heuristic below is only a FALLBACK for
/// ingredients with no rule (unknown items / raw E-numbers off the label).
enum IngredientCategory: String, Codable, CaseIterable {
    case meat, gelatin, enzyme, alcohol
    case seafoodNonFish = "seafood"
    case additive, other

    static func classify(_ ingredient: MatchedIngredient) -> IngredientCategory {
        // Trust the curated rule tag when we have one.
        if let tagged = ingredient.matchedRule?.category { return tagged }
        if let hint = ingredient.categoryHint { return hint }

        // Fallback heuristic for unmatched ingredients.
        let text = (ingredient.displayName + " " + ingredient.originalText).lowercased()

        // A raw "E471"-style token with no rule is still an additive.
        if text.range(of: #"\be\d{3}\b"#, options: .regularExpression) != nil { return .additive }

        if matches(text, ["gelatin", "gelatine", "collagen"]) { return .gelatin }
        if matches(text, ["enzyme", "rennet", "lipase", "pepsin", "protease", "trypsin"]) { return .enzyme }
        if matches(text, ["alcohol", "ethanol", "wine", "beer", "liquor", "rum", "brandy", "vodka", "spirit"]) { return .alcohol }
        if matches(text, ["shrimp", "prawn", "crab", "lobster", "shellfish", "clam", "oyster",
                          "squid", "octopus", "mussel", "scallop", "crustacean", "calamari"]) { return .seafoodNonFish }
        if matches(text, ["beef", "chicken", "meat", "poultry", "lamb", "mutton", "goat",
                          "pork", "swine", "bacon", "ham", "lard", "tallow", "broth", "stock", "carmine"]) { return .meat }
        if ingredient.matchedRule?.eNumber != nil { return .additive }
        return .other
    }

    /// Substances that are categorically prohibited and must NEVER be softened by
    /// any standard, even the lenient one.
    /// A rule whose curated verdict is haram (pork, lard, wine and the spirits
    /// listed with it) is pinned too, so "rum" can't grade softer than "wine".
    /// Plain "alcohol" / ethanol is NOT pinned: it grades on the cited
    /// non-khamr alcohol cells (the rule's own display name says "Ethanol").
    /// Words match at word starts only: "pigment", "graham" and "liquorice" are
    /// not pork or khamr.
    static func isHardHaram(_ ingredient: MatchedIngredient) -> Bool {
        if ingredient.matchedRule?.verdict == .haram { return true }
        // The matcher's exceptions apply here too: "root beer", "chocolate liquor",
        // "no alcohol or pork" are not khamr or pork.
        let text = RulesEngine.unmasked((ingredient.displayName + " " + ingredient.originalText).lowercased())
        if ENumberReference.animalOrigin(from: text) == .animalPork { return true }
        return khamrOrProhibited.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static let khamrOrProhibited = try! NSRegularExpression(pattern:
        "(?<![\\p{L}\\p{N}])(?:wine|khamr|beer|(?<!chocolate |cocoa |cacao )liquor(?!ice)|blood(?! orange)|carrion)")

    private static func matches(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }
}

// MARK: - The verdict transform (RETIRED in Phase 2)
//
// `adjustedVerdict(base:for:)` has been REPLACED by the seeded `GradeMatrix`
// (Services/GradeMatrix.swift). Per-standard grading now flows:
//
//     MatchedIngredient.grade → GradeMatrix.cell(for:) → grade.coarse → verdict
//
// The matrix carries the full reduced 4-position table from Build Spec v2 §1
// (all needsReview = true) and pins porcine/khamr to Haram for every standard.
// `IngredientCategory.classify(_:)` and `isHardHaram(_:)` below are RETAINED —
// the matrix's subject resolver and hard-haram pin both use them.
//
// NOTE (carried gap for the scholar queue): the old transform escalated
// `seafoodNonFish` to Haram under .hanafiStrict (fish-only). The reduced §1
// matrix has no seafood row yet, so that lever is currently NOT reproduced —
// flag for a seeded seafood row in a follow-up.

// MARK: - Certification bodies → standards satisfied

/// Major halal certifiers. Used to label a scan as "certified to your standard"
/// vs "certified, but to a looser standard than yours."
enum CertificationBody: String, CaseIterable, Identifiable, Codable {
    case ifanca, isna, hfsaa, ahf, hmc, hfa, jakim, mui, esma

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ifanca: return "IFANCA"
        case .isna:   return "ISNA"
        case .hfsaa:  return "HFSAA"
        case .ahf:    return "AHF"
        case .hmc:    return "HMC"
        case .hfa:    return "HFA"
        case .jakim:  return "JAKIM"
        case .mui:    return "MUI"
        case .esma:   return "ESMA"
        }
    }

    var fullName: String {
        switch self {
        case .ifanca: return "Islamic Food & Nutrition Council of America"
        case .isna:   return "Islamic Society of North America — Halal"
        case .hfsaa:  return "Halal Food Standards Alliance of America"
        case .ahf:    return "American Halal Foundation"
        case .hmc:    return "Halal Monitoring Committee (UK)"
        case .hfa:    return "Halal Food Authority (UK)"
        case .jakim:  return "Dept. of Islamic Development Malaysia (MS1500)"
        case .mui:    return "Majelis Ulama Indonesia (LPPOM MUI)"
        case .esma:   return "UAE National Halal (ESMA / MOIAT)"
        }
    }

    /// Standards this body's certification is mapped to satisfy.
    ///
    /// PENDING DATA, not an assertion: these are draft mappings reduced from the
    /// fiqh draft §4 (a body satisfies a position if it is at least as strict as
    /// it). Like every grade cell, each pairing stays pending until backed by a
    /// citation to the body's own published criteria in Citations.json — the
    /// certifier "meets your standard?" badge speaks only as strongly as that
    /// data allows. The meat/non-meat split (whether .zabiha should require
    /// hand-slaughter separately) is an open pending question, not a decided one.
    var confidentlySatisfies: Set<HalalStandard> {
        switch self {
        case .hfsaa, .hmc:
            // Hand-slaughter, no-stun, strict additives → satisfy every position.
            return [.zabiha, .hanafiStrict, .general, .lenient]
        case .jakim, .mui, .esma:
            // Strict on added alcohol; accept reversible-stun/mechanical → not zabiha.
            return [.hanafiStrict, .general, .lenient]
        case .ifanca, .isna, .ahf:
            // Mainstream US; accept mechanical slaughter → general/lenient only.
            return [.general, .lenient]
        case .hfa:
            // UK mainstream; permits mechanical slaughter and pre-stunning → looser.
            return [.general, .lenient]
        }
    }

    /// Standards where satisfaction is PLAUSIBLE but unverified — shown to the
    /// user as "may meet" / flagged, never asserted.
    ///
    /// Empty for now: the previously-uncertain hanafiStrict mappings were folded
    /// into `confidentlySatisfies` per the draft §4 reduction. If the open
    /// meat/non-meat split is later adopted (as cited pending data), non-meat-only
    /// satisfactions would surface here.
    var uncertainlySatisfies: Set<HalalStandard> {
        []
    }
}

extension CertificationBody {
    /// Detect a KNOWN certifier from Open Food Facts label tokens
    /// (e.g. "en:halal", "en:ifanca", "en:jakim"). Returns nil when no specific
    /// body is recognized — coverage in OFF is spotty, so a nil here is common.
    static func detect(in labels: [String]) -> CertificationBody? {
        let haystack = labels.map { $0.lowercased() }.joined(separator: " ")
        let tokens: [(CertificationBody, [String])] = [
            (.ifanca, ["ifanca"]),
            (.isna,   ["isna"]),
            (.hfsaa,  ["hfsaa"]),
            (.ahf,    ["ahf", "american-halal", "american halal"]),
            (.hmc,    ["hmc", "halal-monitoring", "halal monitoring"]),
            (.hfa,    ["hfa", "halal-food-authority", "halal food authority"]),
            (.jakim,  ["jakim"]),
            (.mui,    ["mui", "lppom"]),
            (.esma,   ["esma"]),
        ]
        // Short codes must be whole words: a free-text tag like "fr:desmarais"
        // is not ESMA, "en:muir-glen" is not MUI.
        let words = Set(haystack.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        for (body, keys) in tokens where keys.contains(where: { $0.contains(where: { !$0.isLetter }) ? haystack.contains($0) : words.contains($0) }) {
            return body
        }
        return nil
    }

    /// Whether the product carries any generic "halal" label (no specific body).
    static func hasGenericHalalLabel(_ labels: [String]) -> Bool {
        labels.contains {
            let t = $0.lowercased()
            return t.contains("halal") && t.range(of: #"(?:non|not|no)[- ]halal"#, options: .regularExpression) == nil
        }
    }
}

/// How a product's certification relates to the user's chosen standard.
enum StandardSatisfaction {
    case meetsYourStandard          // draft says it satisfies AND that claim is cited
    case pendingCitation            // draft says it satisfies but the claim isn't cited yet
    case looserThanYours            // certified, but to a looser standard
    case possiblyMeets              // plausible but unverified (uncertain mapping)
    case unknown                    // no certifier detected on the product

    /// Gated by the SAME citation rule as a grade cell (Citation Protocol §8): a
    /// confident "meets your standard" requires the satisfaction claim to be
    /// cited; an uncited positive claim renders as pending, never confident.
    static func evaluate(body: CertificationBody?, against standard: HalalStandard) -> StandardSatisfaction {
        guard let body else { return .unknown }
        let claim = SatisfactionClaim.make(body: body, standard: standard)
        if claim.draftSatisfies {
            return claim.isCited ? .meetsYourStandard : .pendingCitation
        }
        if body.uncertainlySatisfies.contains(standard) { return .possiblyMeets }
        return .looserThanYours
    }
}

// WIRED: StandardSatisfaction is surfaced on the verdict screen via
// CertificationStatusView, using CertificationBody.detect(in: product.labels).
// Open Food Facts `labels_tags` is parsed by OpenFoodFactsService into
// Product.labels. NOTE: OFF coverage of SPECIFIC certifiers is spotty — most
// products yield only a generic "halal" label (or nothing), so the badge often
// shows "Labeled halal — certifier not identified" rather than a body.
// The body→standard satisfaction sets are pending data: each pairing firms up
// only when cited to the certifier's published criteria in Citations.json.

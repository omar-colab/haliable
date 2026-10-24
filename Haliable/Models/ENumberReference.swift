//
//  ENumberReference.swift
//  Haliable
//
//  Phase 3 — the E-number ⇄ origin reference. Two jobs:
//   1. `origins`: each E-number's possible source set, so the UI can say "could be
//      plant or animal" and so a SINGLE-possibility additive can auto-resolve its
//      origin (e.g. carmine → insect).
//   2. `nameToENumber`: recognized US ingredient names → E-number, so USDA-sourced
//      products (which arrive with `additivesENumbers` empty) can still be mapped.
//
//  ⚠️ DRAFT (needsReview): origin sets are seeded from the v1 additive notes and
//  must be scholar/source-verified. Used only to pick a grade cell — never to
//  assert a ruling on its own.
//

import Foundation

enum ENumberReference {

    /// E-number → its plausible origin(s). Order is not significant.
    static let origins: [String: [Origin]] = [
        "E120":  [.insect],                          // carmine / cochineal
        "E322":  [.plant, .animal],                  // lecithin (soy dominant; can be egg)
        "E422":  [.plant, .animal, .synthetic],      // glycerin / glycerol
        "E441":  [.animalPork, .animalNonZabiha, .plant], // gelatin
        "E470":  [.plant, .animal],                  // stearic acid / stearates
        "E471":  [.plant, .animal],                  // mono/diglycerides
        "E472":  [.plant, .animal],                  // esters
        "E542":  [.animalNonZabiha],                 // bone phosphate
        "E570":  [.plant, .animal],                  // stearic acid
        "E627":  [.synthetic, .animal, .plant],      // disodium guanylate
        "E631":  [.synthetic, .animal, .plant],      // disodium inosinate
        "E901":  [.insect],                          // beeswax
        "E904":  [.insect],                          // shellac
        "E920":  [.animal, .synthetic],              // L-cysteine
        "E153":  [.plant, .animalNonZabiha],         // vegetable/bone carbon
        "E1105": [.animal, .microbial],              // lysozyme (often egg)
        // Proposed Oct 23 (pending approval): one possible origin each.
        "E200":  [.synthetic],                   // sorbic acid
        "E250":  [.synthetic],                   // sodium nitrite
        "E301":  [.synthetic],                   // sodium ascorbate
        "E339":  [.synthetic],                   // sodium phosphates
        "E340":  [.synthetic],                   // potassium phosphates
        "E406":  [.plant],                       // agar (seaweed)
        "E407":  [.plant],                       // carrageenan (seaweed)
        "E414":  [.plant],                       // gum arabic (acacia)
        "E440":  [.plant],                       // pectin (fruit)
        "E460":  [.plant],                       // cellulose
        "E461":  [.plant],                       // methyl cellulose
    ]

    /// Recognized US ingredient names → E-number (for the USDA text path).
    static let nameToENumber: [String: String] = [
        "carmine": "E120", "cochineal": "E120", "carminic acid": "E120",
        "lecithin": "E322",
        "glycerin": "E422", "glycerol": "E422", "glycerine": "E422",
        "gelatin": "E441", "gelatine": "E441",
        "stearic acid": "E470", "magnesium stearate": "E470", "stearate": "E570",
        "mono and diglycerides": "E471", "mono- and diglycerides": "E471",
        "monoglycerides": "E471", "diglycerides": "E471",
        "bone phosphate": "E542",
        "disodium inosinate": "E631", "disodium guanylate": "E627",
        "beeswax": "E901", "shellac": "E904", "confectioner's glaze": "E904",
        "l-cysteine": "E920", "cysteine": "E920",
    ]

    /// Infer a concrete origin from free text when a qualifier is named on the
    /// label (e.g. "soy lecithin", "beef gelatin"). Returns nil when undisclosed,
    /// which the caller treats as `.unspecified` (never resolves below Mashbooh).
    /// Animal sources are checked first, so a label naming both ("soy and/or
    /// beef") takes the stricter one.
    static func inferOrigin(from text: String) -> Origin? {
        animalOrigin(from: text) ?? nonAnimalOrigin(from: text)
    }

    /// Pork / land-animal qualifiers. Callers scan these pessimistically over
    /// everything the label says about an ingredient. "pork-free" is not a source.
    static func animalOrigin(from text: String) -> Origin? {
        let lower = text.lowercased()
        let t = negations.stringByReplacingMatches(
            in: lower, range: NSRange(lower.startIndex..., in: lower), withTemplate: " ")
        if has(pork, t) { return .animalPork }
        if has(bovine, t) { return .animalNonZabiha }
        if has(animal, t) { return .animal }
        return nil
    }

    /// Plant / synthetic qualifiers. These LOWER a grade, so callers pass only the
    /// phrase the qualifier is attached to ("gelatin and soy lecithin" must not
    /// make the gelatin plant-based).
    static func nonAnimalOrigin(from text: String) -> Origin? {
        let t = text.lowercased()
        if has(plant, t) { return .plant }
        if has(synthetic, t) { return .synthetic }
        return nil
    }

    // Word-start anchored, so "pig" can't fire inside "pigment" or "plant" inside
    // "plantain". Accents are already folded by IngredientParser.normalize.
    private static func rx(_ alternatives: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}])(?:" + alternatives + ")")
    }
    private static let pork = rx("pork|porcine|swine|bacon|lard|pigs?(?![\\p{L}])|pigskin|ham(?![\\p{L}])|porc(?![\\p{L}])|cerdo|babi(?![\\p{L}])|domuz|schwein|maiale|suino|varken|porco|خنزير")
    private static let bovine = rx("beef|bovine|cattle|calf|tallow|veal|boeuf|bœuf|vacuno|res(?![\\p{L}])|sapi(?![\\p{L}])|lembu|sigir")
    private static let animal = rx("animal|mammal|hewan|haiwan")
    private static let plant = rx("corn|maize|potato|tapioca|seaweed|algae|soy|sunflower|vegetable|vegetal|plant|palm|canola|coconut|rapeseed|vegan|soja|tournesol|colza|kedelai|bitkisel|nabati")
    private static let synthetic = rx("synthetic|fermentation|fermented|microbial")
    private static let negations = try! NSRegularExpression(pattern:
        "(?:no|non|free from|without|sans|sin|ohne)[ -](?:pork|porcine|animal|beef)|(?:pork|porcine|animal|beef)[ -]free"
        + "|kein(?:e|en|er)? schweine\\p{L}*|(?:do(?:es)? not|does?n.?t|never|will not) contain(?:s)?(?: any)?[^.;]*|contains? no [^.;]*|(?:لا [يت]حتوي|خال[يى]?[ةه]? من|بدون)[^.;،]*|h[iı]cbir[^.,;]*|(?:alkol|domuz)[^.;]*(?:yoktur|kullan[iı]lmamaktad[iı]r|kat[iı]lmam[iı]st[iı]r|i[cç]ermez)"
        // "turkey bacon" is turkey; the turkey is still graded as meat.
        + "|(?<=turkey |chicken |beef )(?:bacon|ham)")

    private static func has(_ re: NSRegularExpression, _ t: String) -> Bool {
        re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil
    }
}

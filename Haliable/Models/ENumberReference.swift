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
    static func inferOrigin(from text: String) -> Origin? {
        let t = text.lowercased()
        if t.containsAny(["pork", "swine", "bacon", "lard", "pig", "porcine"]) { return .animalPork }
        if t.containsAny(["beef", "bovine", "cattle", "calf", "tallow"])       { return .animalNonZabiha }
        if t.containsAny(["soy", "sunflower", "vegetable", "plant", "palm", "canola", "coconut", "rapeseed"]) { return .plant }
        if t.containsAny(["synthetic", "fermentation", "fermented", "microbial"]) { return .synthetic }
        return nil
    }
}

extension String {
    /// True if any needle is a substring. Small helper used by origin inference.
    func containsAny(_ needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }
}

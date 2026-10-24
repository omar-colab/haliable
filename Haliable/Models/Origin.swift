//
//  Origin.swift
//  Haliable
//
//  Phase 1 (grading model refactor): the origin dimension for an ingredient.
//  The same category (gelatin, lecithin, L-cysteine, …) grades very differently
//  depending on its source, so the engine grades on origin AS WELL AS category
//  and standard.
//
//  The default for a scanned US label is `.unspecified`. Per spec §2b, an
//  unspecified-origin contested item must NEVER resolve to `.halal`; that rule is
//  enforced where grades are produced (GradeMatrix, Phase 2), not here.
//

import Foundation

enum Origin: String, Codable, CaseIterable, Hashable {
    case plant
    case animal             // animal-derived, slaughter status unknown
    case animalPork         // pork-derived — hard-haram regardless of standard
    case animalNonZabiha    // land animal, not verified zabiha
    case insect
    case synthetic
    case mineral            // mined / inorganic salts (chalk, phosphates)
    case microbial          // e.g. microbial rennet / FPC
    case unspecified        // the common scanned-label case

    var displayName: String {
        switch self {
        case .plant:           return "Plant"
        case .animal:          return "Animal (source unverified)"
        case .animalPork:      return "Pork-derived"
        case .animalNonZabiha: return "Animal (non-zabiha)"
        case .insect:          return "Insect-derived"
        case .synthetic:       return "Synthetic"
        case .mineral:         return "Mineral"
        case .microbial:       return "Microbial / fermentation"
        case .unspecified:     return "Source not disclosed"
        }
    }
}

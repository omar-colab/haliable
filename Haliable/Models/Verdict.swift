//
//  Verdict.swift
//  Haliable
//
//  Created by Omar O on 5/23/26.
//

import Foundation

// The three rulings Haliable can return.
//
// IMPORTANT: the raw values stay "halal"/"haram"/"doubtful" so the bundled
// rules JSON and any saved history keep decoding. The user-facing word for
// `doubtful` is "Questionable" — exposed via `displayName` — because the
// product's design promise is that ambiguous ingredients get an honest
// "we're not sure, here's why," never a forced binary.
enum Verdict: String, Codable, CaseIterable, Hashable {
    case halal
    case haram
    case doubtful

    /// The word shown to users. `doubtful` reads as "Questionable".
    var displayName: String {
        switch self {
        case .halal:    return "Halal"
        case .haram:    return "Haram"
        case .doubtful: return "Questionable"
        }
    }

    /// Worst-case ordering used by the roll-up: a single haram outranks
    /// everything; a single questionable outranks halal. Higher = worse.
    var severity: Int {
        switch self {
        case .halal:    return 0
        case .doubtful: return 1
        case .haram:    return 2
        }
    }
}

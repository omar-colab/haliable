//
//  GradeLevel.swift
//  Haliable
//
//  Phase 1 (grading model refactor): the 5-level grade that will become the
//  engine's internal ruling, giving the owner's original "accepted by many vs.
//  widely disapproved" depth that the 3-value Verdict can't express.
//
//  BLAST-RADIUS CONTROL: the existing app, persistence (ScanRecord), and tests
//  all still speak `Verdict`. GradeLevel bridges back via `coarse`, so no
//  downstream call site has to change until we deliberately migrate it.
//
//  ⚠️ FIQH: this file defines only the SCALE. No fiqh values live here — the
//  per-(category, origin, standard) cells are seeded in Phase 2 from
//  Haliable_Grading_Build_Spec v2 §1, and every produced cell stays needsReview.
//

import Foundation

/// Haliable's 5-level grade taxonomy (matches the fiqh draft's 1–5 scale).
/// Higher raw value = stricter / worse, so `max(...)` still yields worst-case.
enum GradeLevel: Int, Comparable, Codable, CaseIterable, Hashable {
    case halal = 1                 // 1 — clear
    case mashboohSafe = 2          // 2 — doubtful, widely accepted safe
    case mashboohContested = 3     // 3 — doubtful, genuinely contested
    case mashboohDisapproved = 4   // 4 — doubtful, widely disapproved
    case haram = 5                 // 5 — clear

    static func < (lhs: GradeLevel, rhs: GradeLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Worst-case ordering, mirroring `Verdict.severity` (higher = worse).
    var severity: Int { rawValue }

    /// Collapse the 5 levels back to the legacy 3-value `Verdict`. This is the
    /// migration bridge: every existing `Verdict` site keeps working by reading
    /// `someGrade.coarse`.
    var coarse: Verdict {
        switch self {
        case .halal:
            return .halal
        case .haram:
            return .haram
        case .mashboohSafe, .mashboohContested, .mashboohDisapproved:
            return .doubtful
        }
    }

    /// INTERIM (Phase 1 only): lift a legacy 3-value `Verdict` into the 5-level
    /// scale so the new type can be exercised and reviewed BEFORE the GradeMatrix
    /// is wired in. The middle maps to `.mashboohContested` (the neutral
    /// "genuinely contested" tier). Phase 2 removes this in favor of real cells.
    static func lifted(from verdict: Verdict) -> GradeLevel {
        switch verdict {
        case .halal:    return .halal
        case .haram:    return .haram
        case .doubtful: return .mashboohContested
        }
    }

    /// User-facing label. The three middle tiers expose the "how contested"
    /// depth the 3-value model couldn't show.
    var displayName: String {
        switch self {
        case .halal:               return "Halal"
        case .mashboohSafe:        return "Questionable — widely accepted"
        case .mashboohContested:   return "Questionable — contested"
        case .mashboohDisapproved: return "Questionable — widely avoided"
        case .haram:               return "Haram"
        }
    }
}

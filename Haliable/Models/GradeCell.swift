//
//  GradeCell.swift
//  Haliable
//
//  One graded cell + its provenance + the published `citations` that back a
//  reported position (Citation Protocol §7). The clearance invariant (§8) is
//  enforced HERE, in the computed `needsReview`, so it can never be bypassed:
//  citations are data (Citations.json) and the gate is code.
//
//  ⚠️ A cell clears (`needsReview == false`) ONLY when ALL hold:
//    1. ≥1 citation of tier .standardBody or .peerReviewed,
//    2. if `isHighTraffic` OR position == .lenient → ≥2 INDEPENDENT such
//       citations (distinct source identity),
//    3. every citation is well-formed (name + reference + date + paraphrase),
//    4. an origin-undeterminable cell may clear only to a NON-halal grade.
//  Otherwise it is pending. No code edit clears a cell — only real citations do.
//

import Foundation

/// How well-sourced a cell's grade is (carried from the draft's confidence column).
enum Confidence: String, Codable, CaseIterable, Hashable {
    case high
    case medium
    case low
}

/// Where a cell stands on the clearance path — drives the worksheet status column.
enum CitationStatus: String, Codable, Hashable {
    case pending           // no clearing citation yet (or undeterminable→halal blocked)
    case needsSecondSource // has one strong citation but needs a 2nd independent one
    case cited             // fully cleared
}

/// A single graded outcome for (subject, origin, position).
struct GradeCell: Codable, Hashable {
    let grade: GradeLevel
    let confidence: Confidence
    /// Short internal provenance (e.g. "Spec §1: …"). Distinct from `citations`,
    /// which are the published, user-checkable sources.
    let source: String
    /// Published-source evidence backing the reported position (data from Citations.json).
    let citations: [Citation]
    /// Drives the two-source requirement (§8.2). Seeded from the high-traffic list
    /// / field-validation frequency.
    let isHighTraffic: Bool
    /// The position this cell grades under — `.lenient` always needs two sources.
    let position: HalalStandard
    /// True when the US label can't reveal the origin (§8.4) — such a cell can
    /// never be cleared to halal, only documented as doubtful.
    let originUndeterminable: Bool

    init(grade: GradeLevel, confidence: Confidence, source: String,
         citations: [Citation] = [], isHighTraffic: Bool = false,
         position: HalalStandard = .general, originUndeterminable: Bool = false) {
        self.grade = grade
        self.confidence = confidence
        self.source = source
        self.citations = citations
        self.isHighTraffic = isHighTraffic
        self.position = position
        self.originUndeterminable = originUndeterminable
    }

    // MARK: - Clearance invariant (§8)

    /// Citations strong enough to count: tier 1/2 AND well-formed.
    var clearingCitations: [Citation] { citations.filter { $0.clears } }

    /// Distinct organizations/authors among the clearing citations.
    var independentSourceCount: Int { Set(clearingCitations.map(\.sourceIdentity)).count }

    /// Two independent sources required: high-traffic cells, and every `.lenient`
    /// cell (a synthesized "most permissive defensible" stance must trace to ≥2
    /// real published positions, never "some say it's fine").
    var requiresTwoSources: Bool { isHighTraffic || position == .lenient }

    /// The §8 gate. False unless every rule is satisfied.
    var isCleared: Bool {
        guard !clearingCitations.isEmpty else { return false }          // §8.1 + §8.3
        if requiresTwoSources && independentSourceCount < 2 { return false } // §8.2
        if originUndeterminable && grade == .halal { return false }    // §8.4
        return true
    }

    /// True until the cell is cleared. The UI shows the pending-review treatment
    /// whenever this holds; the grade stays its conservative fail-safe value.
    var needsReview: Bool { !isCleared }

    /// Worksheet/UI status.
    var citationStatus: CitationStatus {
        if isCleared { return .cited }
        if !clearingCitations.isEmpty && requiresTwoSources && independentSourceCount < 2 {
            return .needsSecondSource
        }
        return .pending
    }

    // MARK: - Contested (§1A / §12)

    /// A genuinely contested cell: a contested grade carrying ≥2 citations (the
    /// differing positions). The verdict UI renders both rather than forcing a pick.
    var isContested: Bool { grade == .mashboohContested && citations.count >= 2 }

    /// One line per cited position — a contested cell yields one per source.
    var citationSummaries: [String] { citations.map(\.oneLine) }
}

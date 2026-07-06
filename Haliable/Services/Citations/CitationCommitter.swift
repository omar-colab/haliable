//
//  CitationCommitter.swift
//  Haliable
//
//  Citation Pipeline — Component 4 (see docs/citations/SPEC.md). Takes APPROVED
//  candidates, re-validates each against the REAL engine gate (the same
//  `GradeCell.isCleared` / `SatisfactionClaim.isClearedSatisfaction` the app
//  uses — never a copy), and merges the passing ones into `Citations.json`.
//
//  Guarantees:
//   • Single gate    — a candidate that wouldn't clear the live cell is rejected.
//   • No fabrication — only `approved` candidates with real, well-formed citations.
//   • Idempotent     — keyed merge; re-committing the same candidate is a no-op.
//   • Reversible     — output is plain JSON under git.
//

import Foundation

enum CitationCommitter {

    /// Outcome for one candidate.
    struct Outcome: Hashable {
        enum Result: String { case committed, rejected, skippedNotApproved }
        let key: String
        let result: Result
        let reason: String
    }

    struct CommitReport: Hashable {
        let committed: Int
        let rejected: Int
        let skipped: Int
        let outcomes: [Outcome]
        /// The merged file, ready to write (or inspect in a test).
        let file: CitationFile
    }

    // MARK: - Validation against the live engine

    /// Would these citations clear THIS cell, using the app's own `GradeCell`
    /// gate? We reconstruct the live cell (same grade/flags) with the proposed
    /// citations and ask it directly — no re-implementation of §8.
    static func wouldClearCell(subject: String, origin: String, position: String,
                               proposed: [Citation]) -> Bool {
        guard let entry = GradeMatrix.allSeededEntries.first(where: {
            $0.subject.reviewLabel == subject
                && $0.origin.rawValue == origin
                && $0.standard.rawValue == position
        }) else { return false }
        let c = entry.cell
        let trial = GradeCell(grade: c.grade, confidence: c.confidence, source: c.source,
                              citations: proposed, isHighTraffic: c.isHighTraffic,
                              position: c.position, originUndeterminable: c.originUndeterminable)
        return trial.isCleared
    }

    /// Would these citations clear THIS certifier claim, using the app's own
    /// `SatisfactionClaim` gate?
    static func wouldClearCertifier(body: String, position: String,
                                    proposed: [Citation]) -> Bool {
        guard let b = CertificationBody(rawValue: body),
              let std = HalalStandard(rawValue: position) else { return false }
        let draft = b.confidentlySatisfies.contains(std)
        let trial = SatisfactionClaim(body: b, standard: std,
                                      draftSatisfies: draft, citations: proposed)
        return trial.isClearedSatisfaction
    }

    private static func validate(_ cand: CitationCandidate) -> (ok: Bool, reason: String) {
        let t = cand.target
        switch t.kind {
        case .cell:
            let ok = wouldClearCell(subject: t.subject, origin: t.origin ?? "unspecified",
                                    position: t.position, proposed: cand.proposed)
            return (ok, ok ? "clears the live cell gate"
                           : "would NOT clear the live cell gate (needs ≥1 tier-1/2 well-formed citation; ≥2 independent if high-traffic/lenient; undeterminable can't go halal)")
        case .certifier:
            let ok = wouldClearCertifier(body: t.subject, position: t.position,
                                         proposed: cand.proposed)
            return (ok, ok ? "clears the live certifier gate"
                           : "would NOT clear the live certifier claim (needs ≥1 tier-1/2 well-formed citation, and the body must draft-satisfy this position)")
        }
    }

    // MARK: - Commit

    /// Merge approved+validated candidates into `existing`. Pure — no file I/O —
    /// so it's trivially testable; callers persist the returned `file`.
    static func commit(_ candidates: [CitationCandidate],
                       into existing: CitationFile) -> CommitReport {
        var cells = Dictionary(uniqueKeysWithValues:
            existing.cells.map { (CitationStore.cellKey(subject: $0.subject, origin: $0.origin, position: $0.position), $0) })
        var certs = Dictionary(uniqueKeysWithValues:
            (existing.certifiers ?? []).map { (CitationStore.certKey(body: $0.body, position: $0.position), $0) })

        var outcomes: [Outcome] = []
        for cand in candidates {
            let key = cand.target.storeKey
            guard cand.isApproved else {
                outcomes.append(Outcome(key: key, result: .skippedNotApproved,
                                        reason: "decision = \(cand.decision.rawValue)"))
                continue
            }
            let v = validate(cand)
            guard v.ok else {
                outcomes.append(Outcome(key: key, result: .rejected, reason: v.reason))
                continue
            }
            switch cand.target.kind {
            case .cell:
                cells[key] = CitationEntry(subject: cand.target.subject,
                                           origin: cand.target.origin ?? "unspecified",
                                           position: cand.target.position,
                                           citations: cand.proposed)
            case .certifier:
                certs[key] = CertifierCitationEntry(body: cand.target.subject,
                                                    position: cand.target.position,
                                                    citations: cand.proposed)
            }
            outcomes.append(Outcome(key: key, result: .committed, reason: v.reason))
        }

        let file = CitationFile(
            version: max(existing.version, 1),
            cells: cells.values.sorted { $0.subject + $0.origin + $0.position < $1.subject + $1.origin + $1.position },
            certifiers: certs.values.sorted { $0.body + $0.position < $1.body + $1.position }
        )
        return CommitReport(
            committed: outcomes.filter { $0.result == .committed }.count,
            rejected: outcomes.filter { $0.result == .rejected }.count,
            skipped: outcomes.filter { $0.result == .skippedNotApproved }.count,
            outcomes: outcomes,
            file: file
        )
    }

    /// Encode a `CitationFile` exactly as `Citations.json` is shaped.
    static func encode(_ file: CitationFile) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try enc.encode(file)
    }
}

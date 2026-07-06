//
//  CitationCandidate.swift
//  Haliable
//
//  Citation Pipeline — Component 2/3 (see docs/citations/SPEC.md). A staged,
//  reviewable proposal: the citations found for one backlog item, plus the
//  owner's decision. Lives as JSON under `docs/citations/candidates/` between
//  sessions. Only `approved` candidates are eligible for the committer (§4).
//
//  This is a PROPOSAL, not a clearance — the committer still re-validates every
//  approved candidate against the real engine gate before writing anything.
//

import Foundation

/// Which backlog item a candidate targets. Mirrors the `CitationStore` key fields
/// so the committer files the citations under the exact same key.
struct CandidateTarget: Codable, Hashable {
    enum Kind: String, Codable { case cell, certifier }
    let kind: Kind
    let subject: String        // cell: subject label / certifier: body rawValue
    let origin: String?        // cell only
    let position: String       // HalalStandard.rawValue

    var storeKey: String {
        switch kind {
        case .cell:      return CitationStore.cellKey(subject: subject,
                                                      origin: origin ?? "unspecified",
                                                      position: position)
        case .certifier: return CitationStore.certKey(body: subject, position: position)
        }
    }
}

/// The owner's call on a staged candidate (Component 3 — the approval gate).
enum CandidateDecision: String, Codable {
    case staged             // researched, awaiting the owner's review
    case approved           // owner approved → eligible for the committer
    case rejected           // owner rejected outright
    case needsBetterSource  // owner wants a stronger/second source before approving
}

/// One staged proposal for a single backlog item.
struct CitationCandidate: Codable, Hashable {
    let target: CandidateTarget
    /// The real, checkable sources found. Empty is not allowed to commit.
    let proposed: [Citation]
    /// The researcher's (this pipeline's) confidence note + any flags worth the
    /// owner's attention — e.g. "tier-3 only, needs a standards-body doc".
    let researcherNote: String
    var decision: CandidateDecision

    init(target: CandidateTarget, proposed: [Citation],
         researcherNote: String = "", decision: CandidateDecision = .staged) {
        self.target = target
        self.proposed = proposed
        self.researcherNote = researcherNote
        self.decision = decision
    }

    var isApproved: Bool { decision == .approved }

    // MARK: - Disk I/O (docs/citations/candidates)

    /// Load every `*.json` candidate in a directory (skips unreadable files).
    static func load(from directory: URL) -> [CitationCandidate] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: directory,
                                                     includingPropertiesForKeys: nil) else { return [] }
        let dec = JSONDecoder()
        return urls.filter { $0.pathExtension == "json" }.sorted { $0.path < $1.path }
            .compactMap { url in
                (try? Data(contentsOf: url)).flatMap { try? dec.decode(CitationCandidate.self, from: $0) }
            }
    }
}

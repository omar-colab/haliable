//
//  CitationPipeline.swift
//  Haliable
//
//  Citation Pipeline — the on-disk RUNNER that wires components 2→3→4 into the
//  daily loop (see docs/citations/SPEC.md). Three operations, no fabrication:
//
//   • scaffold(...)       — Component 2 on-ramp: emit empty candidate skeletons
//                           for a batch of backlog items, so research has real
//                           slots to fill. Never clobbers an existing file.
//   • reviewSheet(...)    — Component 3: render staged candidates + a live
//                           "would this clear the gate?" preview for the owner.
//   • commitFromDisk(...) — Component 4 persistence: load candidates, commit the
//                           approved+valid ones, WRITE Citations.json, log outcomes.
//
//  The actual sources are still found by hand and approved by the owner — this
//  layer only moves files through the gate, it never invents a citation.
//

import Foundation

enum CitationPipeline {

    // MARK: - Component 2 — scaffold candidate skeletons

    /// A filename-safe slug for a candidate, derived from its store key.
    static func slug(for target: CandidateTarget) -> String {
        target.storeKey
            .replacingOccurrences(of: "::", with: "_")
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
    }

    /// Write an empty `staged` candidate (no citations yet) for each actionable
    /// item into `dir`. Skips blocked items (can't clear as-is) and never
    /// overwrites a file that already exists — so in-progress research is safe.
    /// Returns the paths actually created.
    @discardableResult
    static func scaffold(_ items: [CitationBacklog.Item], into dir: URL) throws -> [URL] {
        let fm = FileManager.default
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        var created: [URL] = []
        for item in items where !item.blocked {
            let target = CandidateTarget(
                kind: item.kind == .certifier ? .certifier : .cell,
                subject: item.subject, origin: item.origin, position: item.position)
            let url = dir.appendingPathComponent("\(slug(for: target)).json")
            guard !fm.fileExists(atPath: url.path) else { continue }   // never clobber research

            let note = "TODO: find \(item.sourcesNeeded) tier-1/2 source(s) " +
                       (item.sourcesNeeded == 2 ? "(must be INDEPENDENT) " : "") +
                       "for \(item.subject) / \(item.origin ?? "—") / \(item.position). " +
                       "Governing body: \(item.governingBody). Leave decision `staged` until the owner approves."
            let cand = CitationCandidate(target: target, proposed: [], researcherNote: note)
            try enc.encode(cand).write(to: url)
            created.append(url)
        }
        return created
    }

    // MARK: - Component 3 — owner review sheet

    /// Render staged candidates with a live gate preview, so the owner can decide
    /// approve / reject / needs-better-source at a glance.
    static func reviewSheet(_ candidates: [CitationCandidate], on date: Date = Date()) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        var md = """
        # Citation candidates for review — \(df.string(from: date))

        \(candidates.count) staged. **Approve** by setting `"decision": "approved"` in the
        candidate's JSON, then run the committer. The "Would clear?" column is the
        REAL engine gate's verdict — a ✗ means even if approved it won't commit.

        | Target | Proposed sources | Would clear? | Decision |
        |---|---|---|---|

        """
        for c in candidates {
            let preview = wouldClear(c)
            let sources = c.proposed.isEmpty
                ? "_(none yet)_"
                : c.proposed.map { "\($0.sourceName) (\($0.tier.shortLabel))" }.joined(separator: " · ")
            md += "| `\(c.target.storeKey)` | \(sources) | \(preview.ok ? "✓" : "✗ " + preview.reason) | \(c.decision.rawValue) |\n"
        }
        md += "\n_Sources are found by hand and verified by the owner. This sheet never invents one._\n"
        return md
    }

    /// The committer's validation, exposed for the review preview.
    static func wouldClear(_ c: CitationCandidate) -> (ok: Bool, reason: String) {
        switch c.target.kind {
        case .cell:
            let ok = CitationCommitter.wouldClearCell(
                subject: c.target.subject, origin: c.target.origin ?? "unspecified",
                position: c.target.position, proposed: c.proposed)
            return (ok, ok ? "" : "needs ≥1 tier-1/2 well-formed citation (≥2 independent if high-traffic/lenient)")
        case .certifier:
            let ok = CitationCommitter.wouldClearCertifier(
                body: c.target.subject, position: c.target.position, proposed: c.proposed)
            return (ok, ok ? "" : "needs ≥1 tier-1/2 well-formed citation; body must draft-satisfy this position")
        }
    }

    // MARK: - Component 4 — commit from disk

    struct DiskCommit {
        let report: CitationCommitter.CommitReport
        let wrote: Bool
    }

    /// Load every candidate in `candidatesDir`, commit the approved+valid ones on
    /// top of the existing `citationsURL` (or an empty file), and write the merged
    /// result back. Idempotent — re-running with no new approvals is a no-op write
    /// of identical content.
    @discardableResult
    static func commitFromDisk(candidatesDir: URL, citationsURL: URL) throws -> DiskCommit {
        let candidates = CitationCandidate.load(from: candidatesDir)
        let existing = (try? Data(contentsOf: citationsURL))
            .flatMap { CitationStore.decode($0) }
            ?? CitationFile(version: 1, cells: [], certifiers: [])

        let report = CitationCommitter.commit(candidates, into: existing)
        let data = try CitationCommitter.encode(report.file)
        try data.write(to: citationsURL)
        return DiskCommit(report: report, wrote: true)
    }

    /// Human-readable audit of a commit run (for the session log / ledger).
    static func auditLog(_ report: CitationCommitter.CommitReport, on date: Date = Date()) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        var md = "# Commit audit — \(df.string(from: date))\n\n"
        md += "\(report.committed) committed · \(report.rejected) rejected · \(report.skipped) skipped.\n\n"
        for o in report.outcomes {
            let mark = o.result == .committed ? "✓" : (o.result == .rejected ? "✗" : "–")
            md += "- \(mark) `\(o.key)` — \(o.result.rawValue): \(o.reason)\n"
        }
        return md
    }
}

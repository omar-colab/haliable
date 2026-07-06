//
//  CitationBacklog.swift
//  Haliable
//
//  Citation Pipeline — Component 1 (see docs/citations/SPEC.md). Enumerates the
//  COMPLETE citation worklist straight from the live engine: every seeded grade
//  cell (`GradeMatrix.allSeededEntries`) and every POSITIVE certifier→standard
//  satisfaction claim (`SatisfactionClaim`). Each item is keyed exactly as
//  `CitationStore` keys it, so a committed citation lands on the right cell.
//
//  This is read-only projection — it authors no fiqh value. A coverage test
//  (`CitationBacklogTests`) asserts the backlog's keys equal what the engine
//  grades on, so the worklist can never drift from the matrix.
//

import Foundation

enum CitationBacklog {

    /// One unit of research work: a single cell or certifier claim to source.
    struct Item: Codable, Hashable {
        enum Kind: String, Codable { case cell, certifier }

        let kind: Kind
        /// Exactly the `CitationStore` key this citation will be filed under.
        let key: String

        // Identity (mirrors the JSON key fields)
        let subject: String          // cell: subject label / certifier: body rawValue
        let origin: String?          // cell only
        let position: String         // HalalStandard.rawValue

        // Context for the researcher
        let governingBody: String
        let draftGrade: Int?         // cell only — 1…5
        let draftGradeName: String?  // cell only
        let draftSatisfies: Bool?    // certifier only
        let isHighTraffic: Bool
        /// 1, or 2 when the gate needs two independent sources (high-traffic / lenient).
        let sourcesNeeded: Int
        let status: String           // "pending" | "needsSecondSource" | "cited"

        /// True when no citation can EVER clear this cell as-is: the US label can't
        /// reveal origin AND the draft grade is halal (§8.4). Needs an origin
        /// signal, not a source — don't burn research time here.
        let blocked: Bool
        let blockedReason: String?
    }

    // MARK: - Enumeration (the single source of truth = the live engine)

    /// Every seeded grade cell, as a backlog item.
    static var cellItems: [Item] {
        GradeMatrix.allSeededEntries.map { e in
            let c = e.cell
            let blocked = c.originUndeterminable && c.grade == .halal
            return Item(
                kind: .cell,
                key: CitationStore.cellKey(subject: e.subject.reviewLabel,
                                           origin: e.origin.rawValue,
                                           position: e.standard.rawValue),
                subject: e.subject.reviewLabel,
                origin: e.origin.rawValue,
                position: e.standard.rawValue,
                governingBody: GradeMatrix.governingBody(for: e.standard),
                draftGrade: c.grade.rawValue,
                draftGradeName: c.grade.displayName,
                draftSatisfies: nil,
                isHighTraffic: c.isHighTraffic,
                sourcesNeeded: c.requiresTwoSources ? 2 : 1,
                status: c.citationStatus.rawValue,
                blocked: blocked,
                blockedReason: blocked
                    ? "origin not determinable from a US label, draft grade is halal — can't clear to halal (§8.4); needs an origin signal, not a citation"
                    : nil
            )
        }
    }

    /// Every POSITIVE certifier→standard claim (the ones that need citing). A body
    /// that doesn't draft-satisfy a position is the conservative direction and
    /// needs no citation, so it's not in the worklist.
    static var certifierItems: [Item] {
        let order: [HalalStandard] = [.zabiha, .hanafiStrict, .general, .lenient]
        var out: [Item] = []
        for body in CertificationBody.allCases {
            for std in order {
                let claim = SatisfactionClaim.make(body: body, standard: std)
                guard claim.draftSatisfies else { continue }
                out.append(Item(
                    kind: .certifier,
                    key: CitationStore.certKey(body: body.rawValue, position: std.rawValue),
                    subject: body.rawValue,
                    origin: nil,
                    position: std.rawValue,
                    governingBody: GradeMatrix.governingBody(for: std),
                    draftGrade: nil,
                    draftGradeName: nil,
                    draftSatisfies: true,
                    isHighTraffic: false,
                    sourcesNeeded: 1,
                    status: claim.isClearedSatisfaction ? "cited" : "pending",
                    blocked: false,
                    blockedReason: nil
                ))
            }
        }
        return out
    }

    /// The full worklist: actionable cells (high-traffic first) then certifier
    /// claims, with permanently-blocked cells sorted last.
    static var items: [Item] {
        let cells = cellItems.sorted { a, b in
            if a.blocked != b.blocked { return !a.blocked }              // actionable first
            if a.isHighTraffic != b.isHighTraffic { return a.isHighTraffic } // high-traffic first
            if a.subject != b.subject { return a.subject < b.subject }
            if a.position != b.position { return a.position < b.position }
            return (a.origin ?? "") < (b.origin ?? "")
        }
        return cells + certifierItems
    }

    // MARK: - Outputs

    struct Snapshot: Codable {
        let version: Int
        let generatedOn: String
        let totalItems: Int
        let actionableCells: Int
        let blockedCells: Int
        let certifierClaims: Int
        let highTraffic: Int
        let items: [Item]
    }

    static func snapshot(on date: Date = Date()) -> Snapshot {
        let all = items
        let cells = all.filter { $0.kind == .cell }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        return Snapshot(
            version: 1,
            generatedOn: df.string(from: date),
            totalItems: all.count,
            actionableCells: cells.filter { !$0.blocked }.count,
            blockedCells: cells.filter { $0.blocked }.count,
            certifierClaims: all.filter { $0.kind == .certifier }.count,
            highTraffic: all.filter { $0.isHighTraffic }.count,
            items: all
        )
    }

    /// `docs/citations/backlog.json`.
    static func json(on date: Date = Date()) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try enc.encode(snapshot(on: date))
    }

    /// Readable `docs/citations/backlog.md` index — high-traffic cells first.
    static func indexMarkdown(on date: Date = Date()) -> String {
        let s = snapshot(on: date)
        var md = """
        # Citation Backlog — \(s.generatedOn)

        Generated from the live engine by `CitationBacklog`. \(s.totalItems) items:
        **\(s.actionableCells) actionable cells**, \(s.blockedCells) blocked (need
        origin, not a citation), \(s.certifierClaims) certifier claims;
        \(s.highTraffic) high-traffic. Research high-traffic (★) first.

        | ★ | Kind | Subject | Origin | Position | Draft | Sources | Status | Blocked |
        |---|---|---|---|---|---|---|---|---|

        """
        for it in s.items {
            let star = it.isHighTraffic ? "★" : ""
            let draft = it.draftGrade.map { "\($0) \(it.draftGradeName ?? "")" } ?? "satisfies"
            let blocked = it.blocked ? "⛔" : ""
            md += "| \(star) | \(it.kind.rawValue) | \(it.subject) | \(it.origin ?? "—") | \(it.position) | \(draft) | \(it.sourcesNeeded) | \(it.status) | \(blocked) |\n"
        }
        md += "\n_Keys match `Citations.json`. Stage candidates in `docs/citations/candidates/`, then commit with `CitationCommitter`._\n"
        return md
    }
}

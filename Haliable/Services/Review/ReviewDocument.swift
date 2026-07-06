//
//  ReviewDocument.swift
//  Haliable
//
//  THE OWNER'S RESEARCH WORKSHEET (Citation Protocol §11). Generated from the
//  LIVE `GradeMatrix` + `Citations.json`, ordered **high-traffic first** then by
//  request frequency, so the owner researches what users actually scan first.
//
//  Model: REPORT, DON'T RULE. Each row is a cell to research against a PUBLISHED
//  source. A cell clears only under the §8 gate (≥1 tier-1/2 well-formed citation;
//  ≥2 independent if high-traffic or lenient; origin-undeterminable never clears
//  to halal). Open levers are listed as ORDINARY pending cells now — not markers.
//
//  Refresh the committed REVIEW.md by running the test target with
//  HALIABLE_WRITE_REVIEW=1 (see ReviewDocumentTests).
//

import Foundation

enum ReviewDocument {

    /// Stable per-cell signature (hidden HTML comment) so the coverage test can
    /// prove every seeded cell is present regardless of rendered wording.
    static func signature(_ e: GradeMatrix.SeededEntry) -> String {
        "cell:\(e.subject.reviewLabel)::\(e.origin.rawValue)::\(e.standard.rawValue)"
    }

    /// Build the worksheet from live data.
    /// - Parameter requestCounts: subject-label → how often users ask about it
    ///   (field-validation / in-app reviews). Ordering is high-traffic first,
    ///   then request frequency, then category order.
    static func generate(generatedOn date: Date = Date(),
                         requestCounts: [String: Int] = [:]) -> String {
        var md = ""
        md += header(date: date, requestCounts: requestCounts)
        md += openLeversSection()
        md += worksheetSection(requestCounts: requestCounts)
        md += certifierSection()
        md += contestedSection()
        md += researcherLog()
        md += footer()
        return md
    }

    /// Generate the worksheet ordered by what's actually been scanned — feeds the
    /// field-validation log's per-subject scan counts into the request ordering.
    static func generate(generatedOn date: Date = Date(), fieldLog: FieldValidationLog) -> String {
        generate(generatedOn: date, requestCounts: fieldLog.subjectCounts())
    }

    // MARK: - Header

    private static func header(date: Date, requestCounts: [String: Int]) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let entries = GradeMatrix.allSeededEntries
        let cited = entries.filter { $0.cell.citationStatus == .cited }.count
        let partial = entries.filter { $0.cell.citationStatus == .needsSecondSource }.count
        let onFile = CitationStore.shared.totalCitationCount
        let ordering = requestCounts.isEmpty
            ? "high-traffic first, then category order (no request data supplied yet)"
            : "high-traffic first, then most-requested"
        return """
        # Haliable — Sourced-Research Worksheet (REPORT, DON'T RULE)

        > **A research worksheet, not a fatwa and not the app's own ruling.**
        > Haliable reports *published* positions with citations the user can check —
        > never a bare "halal/haram" in its own voice. Research each cell against a
        > published source, record the citation in `Citations.json`, and the cell
        > clears. Uncited cells stay visibly pending; the app ships with whatever
        > subset is cited, never guessed.

        Generated from the live `GradeMatrix` + `Citations.json` on
        **\(df.string(from: date))** — \(entries.count) cells; **\(cited) cited, \(partial) need a 2nd source, \(entries.count - cited - partial) pending** (\(onFile) citations on file). Ordered: \(ordering). Regenerate after any change.

        **Clearance gate (enforced in code + tests):** a cell clears ONLY with
        ≥1 **tier-1/2** citation carrying source name + reference + date + paraphrase.
        **High-traffic cells, and every `lenient` cell, need ≥2 INDEPENDENT sources.**
        An **origin-undeterminable** cell (origin not on a US label) can never clear to
        halal — only to a documented non-halal grade. Tier 3 supports but never clears.

        **Source tiers:** 1 = the standard body's own published document (JAKIM/MUI/ESMA/SMIIC, IFANCA/HMC/HFSAA) · 2 = peer-reviewed scholarship (journal / Google Scholar) · 3 = reputable secondary explainer (orienting only).

        **Per-cell procedure:** identify the position's governing body → find its tier-1 stance on this subject/origin → capture name, reference (URL/doc + clause), date, tier, and a paraphrase of what it says → set the grade → for high-traffic/lenient, find a 2nd independent source → if sources split within the position, mark contested with both citations.

        > _Standing disclosure shown in-app on every verdict:_
        > **\(HaliableDisclosure.standing)**

        ---

        """
    }

    // MARK: - 0. Open levers (ordinary pending cells now)

    private static func openLeversSection() -> String {
        var s = """
        ## 0. OPEN LEVERS — high-leverage pending cells

        Four calls with no seeded row / single answer yet. They are ordinary
        pending cells (no special status) — research each against a published
        source and cite it like any other. Listed first because they're consequential.

        """
        for lever in GradeMatrix.openLevers {
            s += """

            ### \(lever.title)

            - **Question:** \(lever.question)
            - **Current behavior in code:** \(lever.liveStatus)
            - **Source name / reference / date / tier:** _______________________________
            - **Paraphrase (what the source says):** ___________________________________
            <!--lever:\(lever.id)-->

            """
        }
        s += "\n---\n\n"
        return s
    }

    // MARK: - 1. Per-cell research worksheet (Protocol §11 columns)

    private static func worksheetSection(requestCounts: [String: Int]) -> String {
        var s = """
        ## 1. Per-cell research worksheet — one row per cell

        High-traffic cells first (`★`). Status: **CITED** (cleared) · **NEEDS 2ND SOURCE**
        (one strong source, needs a second independent one) · **PENDING** (uncited).

        | ★ | Subject | Origin | Position | Governing body | Current grade | Citation status | Paraphrase (on file) |
        |---|---|---|---|---|---|---|---|

        """
        for e in orderedEntries(requestCounts: requestCounts) {
            let star = e.cell.isHighTraffic ? "★" : ""
            let body = GradeMatrix.governingBody(for: e.standard)
            let grade = "\(e.cell.grade.rawValue) — \(e.cell.grade.displayName)"
            let status: String
            switch e.cell.citationStatus {
            case .cited:             status = "CITED"
            case .needsSecondSource: status = "NEEDS 2ND SOURCE"
            case .pending:           status = "PENDING"
            }
            let para = e.cell.clearingCitations.map { mdEscape($0.paraphrase) }.joined(separator: " · ")
            s += "| \(star) | \(e.subject.reviewLabel) | \(e.origin.rawValue) | \(e.standard.displayName) | \(body) | \(grade) | \(status) | \(para) | <!--\(signature(e))-->\n"
        }
        s += """

        > The porcine / khamr **hard-haram pin** (Haram, every position) is enforced
        > in `GradeMatrix.cell(for:)`, not a contestable cell — but still cite the
        > prohibition (e.g. Qur'an 2:173 / 5:3) and confirm the pin's token list.

        ---

        """
        return s
    }

    /// Cells ordered high-traffic first, then by request frequency, then by the
    /// deterministic category → subject → origin → strictness base order.
    private static func orderedEntries(requestCounts: [String: Int]) -> [GradeMatrix.SeededEntry] {
        GradeMatrix.allSeededEntries.enumerated().sorted { a, b in
            let ha = a.element.cell.isHighTraffic, hb = b.element.cell.isHighTraffic
            if ha != hb { return ha && !hb }                            // high-traffic first
            let ra = requestCounts[a.element.subject.reviewLabel] ?? 0
            let rb = requestCounts[b.element.subject.reviewLabel] ?? 0
            if ra != rb { return ra > rb }                              // most-requested next
            return a.offset < b.offset                                   // stable base order
        }.map(\.element)
    }

    // MARK: - 2. Certifier worksheet

    private static func certifierSection() -> String {
        var s = """
        ## 2. Certifier → standard satisfaction (pending data — research + cite)

        Each pairing is pending until cited to the body's OWN published criteria.
        **Open question: should any differ for meat vs non-meat products?**

        | Body | Position | Governing for | Satisfies? (draft) | Source name / reference / date / tier |
        |---|---|---|---|---|

        """
        for row in GradeMatrix.certifierReviewRows {
            let sat = row.satisfies ? "yes" : "no"
            let governs = GradeMatrix.governingBody(for: row.standard)
            s += "| \(row.body.displayName) | \(row.standard.displayName) | \(governs) | \(sat) |  | <!--cert:\(row.body.rawValue)::\(row.standard.rawValue)-->\n"
        }
        s += "\n---\n\n"
        return s
    }

    // MARK: - 3. Contested / divergence

    private static func contestedSection() -> String {
        var s = """
        ## 3. Contested & cross-position appendix

        Cross-position differences are the positions doing their job (not
        "contested"). A cell is **contested** only when sources split *within one
        position* — then it stores BOTH citations. Below: rows where the four
        positions diverge, with how many citations are on file.

        | Subject | Origin | Zabiha | Hanafi-strict | General | Lenient | Source | Citations on file |
        |---|---|---|---|---|---|---|---|

        """
        for row in GradeMatrix.divergentRows {
            let byStd = Dictionary(uniqueKeysWithValues: row.cells.map { ($0.standard, $0.cell.grade.rawValue) })
            func g(_ std: HalalStandard) -> String { byStd[std].map(String.init) ?? "—" }
            let citeCount = row.cells.reduce(0) { $0 + $1.cell.citations.count }
            s += "| \(row.subject.reviewLabel) | \(row.origin.rawValue) | \(g(.zabiha)) | \(g(.hanafiStrict)) | \(g(.general)) | \(g(.lenient)) | \(row.source) | \(citeCount) |\n"
        }
        s += "\nGrades: 1 Halal · 2 Questionable-widely-accepted · 3 Questionable-contested · 4 Questionable-widely-avoided · 5 Haram.\n"
        s += "\n---\n\n"
        return s
    }

    // MARK: - 4. Researcher log

    private static func researcherLog() -> String {
        """
        ## 4. Researcher sourcing log

        Who did the sourcing, when, and against which corpora — so the trail is
        auditable and a scholar can later verify or extend it.

        - **Researcher:** _______________________________________
        - **Date(s) of research:** ______________________________
        - **Sources consulted** (standards bodies' docs, journals/Google Scholar): __________________________
        - **Field-validation scans logged** (gtin · product · position · grade · looked right?): ____________
        - **Items cleared this pass** (subject · origin · position): ______________________________________
        - **Items still pending** (left uncited on purpose): _____________________________________________

        ---

        """
    }

    // MARK: - Footer

    private static func footer() -> String {
        """
        _Generated from code by `ReviewDocument.generate()`. `ReviewDocumentTests`
        asserts it covers every seeded cell and enforces the §8 gate (no clearance
        without a tier-1/2 well-formed citation; two independent for high-traffic /
        lenient; origin-undeterminable never halal). Citations live in
        `Citations.json` — don't hand-edit grades here._

        **\(HaliableDisclosure.standing)**
        """
    }

    // MARK: - Helpers

    private static func mdEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "|", with: "\\|")
         .replacingOccurrences(of: "\n", with: " ")
    }
}

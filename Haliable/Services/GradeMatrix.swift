//
//  GradeMatrix.swift
//  Haliable
//
//  Phase 2 — SEEDED. This replaces `HalalStandard.adjustedVerdict`. It maps a
//  matched ingredient to a per-standard GradeCell, where the grade comes from the
//  reduced 4-position matrix in Haliable_Grading_Build_Spec v2 §1.
//
//  ⚠️ FIQH GATE: every cell is `needsReview = true` — DRAFT values pending
//  qualified-scholar sign-off. Nothing here ships as an authoritative ruling.
//
//  Safety model (carried from the dossier — "a false Halal is the unforgivable
//  error"):
//   1. Hard-haram substances (porcine, khamr) are PINNED to Haram for every
//      standard, before the table is consulted — no standard can soften them.
//   2. Subjects the spec table doesn't cover defer to the rule's curated baseline
//      verdict (a nil rule = Questionable), never silently to Halal.
//
//  Resolution order for a subject: named special-case → E-number → category,
//  taking the first that has a seeded row (so e.g. gelatin's E441, which has no
//  E-number row, falls through to the gelatin category row).
//

import Foundation

struct GradeMatrix {

    /// What a seeded row is keyed on.
    enum Subject: Hashable {
        case category(IngredientCategory)
        case eNumber(String)        // normalized upper-case, e.g. "E120"
        case named(String)          // spec rows that are neither a clean category
                                    // nor a single E-number (e.g. "vanilla extract")
    }

    // MARK: - Public entry points

    /// The cutover entry point: resolve a matched ingredient to its grade cell.
    static func cell(for ingredient: MatchedIngredient) -> GradeCell {
        let origin = resolveOrigin(for: ingredient)
        let standard = ingredient.standard

        // 1. Safety pins — categorically prohibited; never softened by any standard.
        if IngredientCategory.isHardHaram(ingredient) || origin == .animalPork {
            return enriched(grade: .haram, confidence: .high,
                            source: "Spec §1: porcine / khamr — hard-haram pin",
                            subjectLabel: "porcine/khamr", origin: origin, position: standard)
        }

        // 2. First seeded row among the candidate subjects, at this origin (then
        //    falling back to the row's unspecified-origin column).
        for subject in candidateSubjects(for: ingredient) {
            guard let byOrigin = table[subject] else { continue }
            // Which origin row actually answered — used to key the citation lookup.
            let rowOrigin: Origin = byOrigin[origin] != nil ? origin : .unspecified
            guard let byStandard = byOrigin[origin] ?? byOrigin[.unspecified] else { continue }
            guard let bare = byStandard[standard] else { return fallback(origin: origin, standard: standard) }
            return enriched(grade: bare.grade, confidence: bare.confidence, source: bare.source,
                            subjectLabel: subject.reviewLabel, origin: rowOrigin, position: standard)
        }

        // 3. No matrix row → defer to the rule's curated baseline (nil rule =
        //    Questionable). Keeps Phase-1 behavior for anything the spec doesn't cover.
        return enriched(grade: GradeLevel.lifted(from: ingredient.baseVerdict),
                        confidence: .low, source: "rule baseline (no matrix row yet)",
                        subjectLabel: "rule-baseline", origin: origin, position: standard)
    }

    /// "What would make it halal": the origins whose cell for this ingredient's
    /// subject and standard is Halal AND cleared by citations. Reports the
    /// published position only; empty for hard-haram items and uncited rows.
    static func citedHalalOrigins(for ingredient: MatchedIngredient) -> [Origin] {
        let current = resolveOrigin(for: ingredient)
        guard !IngredientCategory.isHardHaram(ingredient), current != .animalPork else { return [] }
        for subject in candidateSubjects(for: ingredient) {
            guard let byOrigin = table[subject] else { continue }
            return byOrigin.keys.filter { origin in
                guard origin != current, origin != .unspecified,
                      let bare = byOrigin[origin]?[ingredient.standard], bare.grade == .halal else { return false }
                return enriched(grade: bare.grade, confidence: bare.confidence, source: bare.source,
                                subjectLabel: subject.reviewLabel, origin: origin,
                                position: ingredient.standard).isCleared
            }.sorted { $0.rawValue < $1.rawValue }
        }
        return []
    }

    /// Low-level lookup by explicit key — used by the fail-safe tests. Unknown
    /// subjects return the conservative non-halal fallback.
    func cell(for subject: Subject, origin: Origin, standard: HalalStandard) -> GradeCell {
        guard let byOrigin = Self.table[subject] else { return Self.fallback(origin: origin, standard: standard) }
        let rowOrigin: Origin = byOrigin[origin] != nil ? origin : .unspecified
        guard let bare = (byOrigin[origin] ?? byOrigin[.unspecified])?[standard] else {
            return Self.fallback(origin: origin, standard: standard)
        }
        return Self.enriched(grade: bare.grade, confidence: bare.confidence, source: bare.source,
                             subjectLabel: subject.reviewLabel, origin: rowOrigin, position: standard)
    }

    /// Conservative placeholder for an unknown/unseeded subject. Never `.halal`.
    static func fallback(origin: Origin = .unspecified,
                         standard: HalalStandard) -> GradeCell {
        enriched(grade: .mashboohContested, confidence: .low,
                 source: "unseeded — conservative fallback",
                 subjectLabel: "unseeded", origin: origin, position: standard)
    }

    // MARK: - Citation enrichment (§7–§9)

    /// Subjects common enough in US packaged food that clearance requires TWO
    /// independent sources (§4 seed list; field-validation frequency refines it).
    /// This is traffic metadata — it only makes the gate STRICTER, never clears.
    static let highTrafficSubjects: Set<String> = [
        "gelatin", "E471", "E322", "natural flavors", "E120", "E422",
        "E470", "whey", "enzyme", "alcohol", "vanilla extract", "flavor ethanol carrier",
    ]

    /// Attach the published citations (from Citations.json) and the §8 inputs to a
    /// bare grade. Every cell the engine returns goes through here, so the
    /// clearance invariant and the data-driven citations apply uniformly.
    static func enriched(grade: GradeLevel, confidence: Confidence, source: String,
                         subjectLabel: String, origin: Origin,
                         position: HalalStandard) -> GradeCell {
        GradeCell(
            grade: grade, confidence: confidence, source: source,
            citations: CitationStore.shared.citations(
                subject: subjectLabel, origin: origin.rawValue, position: position.rawValue),
            isHighTraffic: highTrafficSubjects.contains(subjectLabel),
            position: position,
            originUndeterminable: origin == .unspecified
        )
    }

    // MARK: - Subject resolution

    /// Candidate subjects in priority order; the first with a seeded row wins.
    static func candidateSubjects(for ing: MatchedIngredient) -> [Subject] {
        var candidates: [Subject] = []
        if let id = ing.matchedRule?.id {
            switch id {
            case "vanilla-extract": candidates.append(.named("vanilla extract"))
            case "natural-flavors": candidates.append(.named("natural flavors"))
            case "whey":            candidates.append(.named("whey"))
            // Ethanol named inside a flavouring is the cited "carrier" case, not
            // generic alcohol.
            case "alcohol" where ((ing.labelText ?? ing.originalText).lowercased().contains("flavo")):
                candidates.append(.named("flavor ethanol carrier"))
            default: break
            }
        }
        if ing.categoryHint == nil, ing.matchedRule == nil,
           ing.originalText.lowercased().range(of: #"vitamin d-?3|cholecalciferol"#, options: .regularExpression) != nil {
            candidates.append(.named("vitamin d3"))
        }
        if let e = ing.matchedRule?.eNumber?.uppercased() { candidates.append(.eNumber(e)) }
        else if let e = firstENumber(in: ing.originalText) { candidates.append(.eNumber(e)) }
        candidates.append(.category(IngredientCategory.classify(ing)))
        return candidates
    }

    private static func firstENumber(in text: String) -> String? {
        // 3 or 4 digits: "E1105" must not read as "E110".
        guard let r = text.range(of: #"[Ee]\d{3,4}(?!\d)"#, options: .regularExpression) else { return nil }
        return String(text[r]).uppercased()
    }

    /// The worksheet/citation subject label an ingredient resolves to — the first
    /// candidate subject that has a seeded row, else its classified category.
    /// Used by the field-validation log to count traffic per subject.
    static func subjectLabel(for ing: MatchedIngredient) -> String {
        for subject in candidateSubjects(for: ing) where table[subject] != nil {
            return subject.reviewLabel
        }
        return Subject.category(IngredientCategory.classify(ing)).reviewLabel
    }

    /// The E-number associated with an ingredient, from its rule or its label text.
    private static func eNumber(for ing: MatchedIngredient) -> String? {
        ing.matchedRule?.eNumber?.uppercased() ?? firstENumber(in: ing.originalText)
    }

    /// Resolve the working origin for grading (Phase 3):
    ///  1. an explicit `originAssumption` if the caller set one;
    ///  2. a qualifier named on the label ("soy lecithin" → plant);
    ///  3. a single-possibility E-number (carmine → insect);
    ///  4. otherwise `.unspecified` (never resolves a contested item below Mashbooh).
    static func resolveOrigin(for ing: MatchedIngredient) -> Origin {
        if ing.originAssumption != .unspecified { return ing.originAssumption }
        let text = ing.displayName + " " + ing.originalText
        if let named = ENumberReference.inferOrigin(from: text) { return named }
        if let e = eNumber(for: ing),
           let possibilities = ENumberReference.origins[e],
           possibilities.count == 1 {
            return possibilities[0]
        }
        return .unspecified
    }

    // MARK: - Seeded table (Build Spec v2 §1, reduced 4-position matrix)
    //
    // Rows 1 (porcine) and 2 (khamr alcohol) are enforced by the hard-haram pin
    // above, not stored here. All other rows live below. Columns are
    // zabiha · hanafiStrict · general · lenient. Every cell needsReview = true.

    private static let table: [Subject: [Origin: [HalalStandard: GradeCell]]] = buildTable()

    /// Read-only window onto the live seeded table for the REVIEW.md generator
    /// and its coverage test (`GradeMatrix+Review.swift`). Exposes the SAME
    /// values the engine grades on — no copy, no transform — so the launch-gate
    /// document can't drift from what ships. Does NOT include the porcine/khamr
    /// hard-haram pin, which is enforced in `cell(for:)`, not stored here.
    static var seededTable: [Subject: [Origin: [HalalStandard: GradeCell]]] { table }

    private static func buildTable() -> [Subject: [Origin: [HalalStandard: GradeCell]]] {
        // Seeded cells ship with NO citations → `needsReview` is true by the §A1
        // invariant. To CLEAR a cell, the owner attaches researched citations via
        // the `cites:` argument (≥1 tier-1/2, well-formed); nothing clears here.
        func cell(_ n: Int, _ src: String, cites: [Citation] = []) -> GradeCell {
            GradeCell(grade: GradeLevel(rawValue: n)!, confidence: .medium,
                      source: src, citations: cites)
        }
        func row(_ z: Int, _ h: Int, _ g: Int, _ l: Int, _ src: String) -> [HalalStandard: GradeCell] {
            [.zabiha: cell(z, src), .hanafiStrict: cell(h, src),
             .general: cell(g, src), .lenient: cell(l, src)]
        }

        var t: [Subject: [Origin: [HalalStandard: GradeCell]]] = [:]

        // — Animal / slaughter-dependent —
        t[.category(.gelatin)] = [
            .animalNonZabiha: row(5, 4, 4, 4, "Spec §1: gelatin bovine non-zabiha"),
            .plant:           row(1, 1, 1, 1, "Spec §1: gelatin plant/agar"),
            .microbial:       row(2, 2, 2, 2, "Spec §1: microbial/recombinant gelatin — conditional on halal growth media & host (verify certification)"),
            .unspecified:     row(5, 4, 4, 4, "Spec §1: gelatin unspecified → non-zabiha default"),
        ]
        t[.category(.meat)] = [
            .animalNonZabiha: row(5, 4, 4, 4, "Spec §1: non-zabiha land-animal derivative"),
            .unspecified:     row(5, 4, 4, 4, "Spec §1: non-zabiha land-animal derivative (unspec)"),
        ]
        t[.category(.enzyme)] = [
            .microbial:   row(1, 1, 1, 1, "Spec §1: microbial rennet / FPC"),
            .animal:      row(5, 4, 3, 3, "Spec §1: animal rennet, calf, unverified"),
            .unspecified: row(5, 4, 3, 3, "Spec §1: animal rennet, unverified (unspec)"),
        ]
        t[.named("whey")] = [
            .unspecified: row(4, 3, 3, 3, "Spec §1: whey, rennet source unknown"),
        ]

        // — Insect-derived —
        t[.eNumber("E120")] = [
            .unspecified: row(4, 4, 4, 2, "Spec §1: carmine / cochineal (E120)"),
        ]
        t[.eNumber("E904")] = [
            .unspecified: row(3, 3, 3, 3, "Spec §1: shellac / glaze (E904)"),
        ]
        t[.eNumber("E901")] = [
            .unspecified: row(1, 1, 1, 1, "Spec §1: beeswax (E901) / carnauba"),
        ]

        // — Alcohol carriers (khamr handled by the pin) —
        t[.named("vanilla extract")] = [
            .unspecified: row(4, 4, 3, 2, "Spec §1: vanilla extract (≥35% ethanol, non-khamr)"),
        ]
        t[.named("flavor ethanol carrier")] = [
            .unspecified: row(3, 3, 2, 1, "Spec §1: flavor ethanol carrier — strict positions CONTESTED (Imam Muhammad mufta-bihi avoids vs Abu Hanifa/Abu Yusuf permit non-khamr); final <0.5%, non-khamr"),
        ]
        t[.category(.alcohol)] = [
            // Generic non-khamr alcohol carrier (specific khamr tokens hit the pin).
            .unspecified: row(4, 4, 3, 2, "Spec §1: alcohol carrier (non-khamr) — vanilla-extract tier"),
        ]

        // — Ambiguous-origin additives —
        t[.eNumber("E471")] = [.unspecified: row(4, 4, 3, 3, "Spec §1: mono/diglycerides (E471)")]
        t[.eNumber("E472")] = [.unspecified: row(4, 4, 3, 3, "Spec §1: esters (E472, DATEM)")]
        t[.eNumber("E422")] = [.unspecified: row(4, 4, 3, 3, "Spec §1: glycerin / glycerol (E422)")]
        t[.eNumber("E470")] = [.unspecified: row(4, 3, 3, 3, "Spec §1: magnesium stearate / stearic acid (E470b)")]
        t[.eNumber("E570")] = [.unspecified: row(4, 3, 3, 3, "Spec §1: stearic acid (E570)")]
        t[.eNumber("E920")] = [
            .unspecified: row(4, 4, 3, 3, "Spec §1: L-cysteine (E920) unspecified"),
            .animal:      row(5, 5, 4, 4, "Spec §1: L-cysteine human-hair/animal source"),
            .synthetic:   row(2, 1, 1, 1, "Spec §1: L-cysteine synthetic/fermentation"),
        ]
        t[.eNumber("E631")] = [.unspecified: row(4, 3, 3, 3, "Spec §1: disodium inosinate (E631)")]
        t[.eNumber("E627")] = [.unspecified: row(4, 3, 3, 3, "Spec §1: disodium guanylate (E627)")]
        t[.eNumber("E322")] = [
            .unspecified: row(2, 2, 2, 2, "Spec §1: lecithin (E322) unspecified"),
            .plant:       row(1, 1, 1, 1, "Spec §1: lecithin soy/sunflower/egg (named)"),
        ]
        t[.named("natural flavors")] = [
            .unspecified: row(4, 4, 3, 3, "Spec §1: \"natural flavors\" undisclosed"),
        ]
        t[.eNumber("E542")] = [.unspecified: row(5, 4, 4, 4, "Spec §1: bone phosphate (E542)")]
        t[.eNumber("E153")] = [.unspecified: row(4, 3, 3, 3, "Spec §1: vegetable/bone carbon (E153)")]
        t[.named("vitamin d3")] = [
            .unspecified: row(2, 2, 2, 2, "Spec §1: vitamin D3 / cholecalciferol (lanolin)"),
        ]

        return t
    }
}

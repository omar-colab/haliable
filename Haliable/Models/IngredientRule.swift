//
//  IngredientRule.swift
//  Haliable
//
//  Created by Omar O on 5/25/26.
//

import Foundation

// A "Source" is the citation — which scholar or body, and a link.
struct Source: Codable, Hashable {
    let body: String      // e.g. "IFANCA", "AMJA"
    let title: String
    let url: String
    let year: Int
}

// One rule = one ingredient and its halal ruling.
struct IngredientRule: Codable, Identifiable, Hashable {
    let id: String
    let ingredient: String
    let aliases: [String]      // other names this ingredient goes by
    let eNumber: String?
    /// Curated category that drives the per-standard strictness transform
    /// (meat, gelatin, enzyme, alcohol, seafood, additive, …). Optional with a
    /// nil default so older rule files — and existing callers/tests — still
    /// build, and a missing key decodes as nil. See HalalStandard.swift.
    let category: IngredientCategory?  = nil
    /// Phase 1 (grading refactor): the source(s) this ingredient could come from
    /// (plant/animal/synthetic/…). Drives the per-standard grade alongside
    /// `category`. Optional + decode-tolerant so existing rules-v1.json (which has
    /// no such key) keeps decoding, and a missing key reads as "no origin info".
    /// Values are seeded in Phase 3. Use `possibleOrigins` for a non-optional view.
    let originPossibilities: [Origin]? = nil
    let verdict: Verdict       // <-- uses the enum you wrote yesterday
    let reason: String
    let source: Source

    /// Non-optional view of `originPossibilities` (empty when unknown).
    var possibleOrigins: [Origin] { originPossibilities ?? [] }
}

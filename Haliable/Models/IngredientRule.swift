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
    let verdict: Verdict       // <-- uses the enum you wrote yesterday
    let reason: String
    let source: Source
}

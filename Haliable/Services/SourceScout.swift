//
//  SourceScout.swift
//  Haliable
//
//  Sources on file for uncited ingredients. After a scan, every flagged
//  ingredient with no citation is looked up in `ingredient_research`, where the
//  (now switched-off) `source-scout` bot stored quotes it found word-for-word
//  on their page. One read; nothing is researched.
//
//  Report, don't rule: what it finds is shown as "found automatically, not
//  reviewed yet" beside the grade. It never changes a grade; only Omar's
//  approval through the citation pipeline makes it a citation.
//

import Foundation
import Observation
#if canImport(Supabase)
import Supabase
#endif

@Observable
final class SourceScout {
    struct Source: Decodable, Hashable {
        let name: String
        let url: String
        let tier: Int
        let quote: String
    }
    struct Research: Decodable, Hashable {
        let term: String
        let status: String          // researching | done | failed
        let sources: [Source]
        /// Omar approved these sources from the daily digest email. Grade still unchanged.
        let reviewed: Bool?
    }

    /// Latest known research per term. A term with no entry hasn't been looked
    /// up (or the daily cap held it back).
    private(set) var results: [String: Research] = [:]
    /// Terms this session asked about and is still waiting on.
    private(set) var pending: Set<String> = []

    /// The term to research for a flagged ingredient, or nil when it already
    /// has a citation or isn't a lookup-able ingredient (a meat signal, "no
    /// ingredient information"): rules without a citation, and E-numbers no
    /// rule covers.
    static func term(for item: MatchedIngredient) -> String? {
        if let rule = item.matchedRule {
            return item.citations.isEmpty && item.source == nil ? normalize(rule.ingredient) : nil
        }
        guard item.categoryHint == nil,
              item.originalText.range(of: #"^[Ee]\d{3,4}"#, options: .regularExpression) != nil else { return nil }
        return normalize(item.originalText)
    }

    /// Must match `normalizeTerm` in supabase/functions/_shared/term.ts.
    static func normalize(_ raw: String) -> String? {
        let folded = raw.replacingOccurrences(of: "œ", with: "oe").replacingOccurrences(of: "Œ", with: "oe")
            .replacingOccurrences(of: "æ", with: "ae").replacingOccurrences(of: "Æ", with: "ae")
            .replacingOccurrences(of: "ß", with: "ss")
            .folding(options: .diacriticInsensitive, locale: nil).lowercased()
        let spaced = String(folded.unicodeScalars.map { s -> Character in
            (s.isASCII && (CharacterSet.alphanumerics.contains(s) || s == "-" || s == " ")) ? Character(s) : " "
        })
        var t = spaced.split(separator: " ").joined(separator: " ")
        while let f = t.first, f == "-" || f == " " { t.removeFirst() }
        guard (2...60).contains(t.count), t.split(separator: " ").count <= 6 else { return nil }
        return t
    }

    /// Read what's already on file for every uncited flagged ingredient: one
    /// free read, no research. ($0 mode, Oct 26: the `source-scout` AI is off,
    /// so asking it would only wait on nothing.)
    func research(_ items: [MatchedIngredient]) async {
        let terms = Array(Set(items.compactMap(Self.term(for:)))).sorted().prefix(5)
        guard !terms.isEmpty else { return }
        #if canImport(Supabase)
        guard let client = SupabaseManager.shared else { return }
        pending.formUnion(terms)
        defer { pending.subtract(terms) }
        if let rows: [Research] = try? await client.from("ingredient_research")
            .select("term,status,sources,reviewed").in("term", values: Array(terms)).execute().value {
            for r in rows { results[r.term] = r }
        }
        #endif
    }
}

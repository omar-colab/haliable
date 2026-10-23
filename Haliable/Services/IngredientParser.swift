//
//  IngredientParser.swift
//  Haliable
//
//  Turns a raw Open Food Facts / USDA ingredient statement into something the
//  RulesEngine can match safely:
//
//   1. `normalize` — one canonical spelling: lower-case, accents folded
//      ("gélatine" → "gelatine"), unicode dashes/quotes/brackets unified,
//      E-number spellings collapsed ("E 471", "E-471", "INS 471", "e471i" → "e471"),
//      bare additive numbers after a class name ("emulsifier (471)") tagged as
//      E-numbers, obvious OCR digit swaps inside words ("ge1atin" → "gelatin").
//   2. `parse` — a tree of label items. "chocolate (sugar, soy lecithin), gelatin
//      (beef)" is two top-level items, each with children. Allergen statements
//      ("CONTAINS: MILK, SOY") become their own items, so a "soy" in them can never
//      be read as the source of a neighbouring gelatin.
//
//  This file only reads text. It decides nothing about halal status.
//

import Foundation

struct LabelItem {
    /// The item's own words at its depth, child parentheses removed.
    let own: String
    /// Items listed inside this item's parentheses.
    let children: [LabelItem]
    /// Position in label order (depth-first), for deterministic ordering.
    let index: Int

    /// Own words plus every descendant's words — the full text the label gives it.
    var fullText: String {
        children.isEmpty ? own : own + " (" + children.map(\.fullText).joined(separator: ", ") + ")"
    }

    var descendantsText: String { children.map(\.fullText).joined(separator: ", ") }
}

enum IngredientParser {

    // MARK: - Normalize

    static func normalize(_ raw: String) -> String {
        var t = raw.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                            locale: Locale(identifier: "en_US_POSIX")).lowercased()
        t = t.replacingOccurrences(of: #"[‐-―−﹘﹣－]"#, with: "-",
                                   options: .regularExpression)
        t = t.replacingOccurrences(of: #"[‘’‛ʼ`´]"#, with: "'",
                                   options: .regularExpression)
        t = t.replacingOccurrences(of: #"[\[\{]"#, with: "(", options: .regularExpression)
        t = t.replacingOccurrences(of: #"[\]\}]"#, with: ")", options: .regularExpression)
        // Word hyphenated across a line break: "gela-\ntin" → "gelatin".
        t = t.replacingOccurrences(of: #"(?<=\p{L})-[ \t]*\r?\n\s*(?=\p{L})"#, with: "",
                                   options: .regularExpression)
        // OCR: a 0/1 between two letters is an o/l ("ge1atin", "c0chineal").
        t = t.replacingOccurrences(of: #"(?<=\p{L})0(?=\p{L})"#, with: "o", options: .regularExpression)
        t = t.replacingOccurrences(of: #"(?<=\p{L})1(?=\p{L})"#, with: "l", options: .regularExpression)
        t = t.replacingOccurrences(of: "*", with: " ")
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        t = tagBareAdditiveNumbers(t)
        // E-number spellings → "e471". Sub-variants (i, ii, a, (iii)) are dropped:
        // the tables key on the base code.
        t = t.replacingOccurrences(
            of: #"(?<![\p{L}\p{N}])(?<!vitamin )(?:e|ins)\s?[-.]?\s?(\d{3,4})(?:[a-z]{1,3}|\s?\((?:i|ii|iii|iv|v|vi)\))?(?![\p{L}\p{N}])"#,
            with: "e$1", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// Additive class names that, on AU/NZ/EU labels, introduce bare code numbers:
    /// "emulsifiers (471, 322)" or "colour: 150d".
    private static let additiveClass = try! NSRegularExpression(pattern:
        #"(?<![\p{L}])(emulsifiers?|stabili[sz]ers?|thickeners?|colou?rs?|colou?rings?|flavou?r enhancers?|acidity regulators?|antioxidants?|preservatives?|raising agents?|glazing agents?|gelling agents?|humectants?|firming agents?|sweeteners?|anti-?caking agents?|food acids?)\s?(\(|:)"#)

    private static func tagBareAdditiveNumbers(_ text: String) -> String {
        let ns = text as NSString
        var out = text
        // Walk matches back-to-front so earlier ranges stay valid.
        for m in additiveClass.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            let open = ns.substring(with: m.range(at: 2))
            let start = m.range.location + m.range.length
            var end = start
            while end < ns.length {
                let c = ns.substring(with: NSRange(location: end, length: 1))
                if open == "(" ? c == ")" : (c == ";" || c == "(" || c == ")") { break }
                end += 1
            }
            let span = NSRange(location: start, length: end - start)
            let inner = ns.substring(with: span).replacingOccurrences(
                of: #"(?<![\p{L}\p{N}.,])(\d{3,4})((?:[a-z]{1,3})?)(?![\p{N}%.]|\s?(?:mg|g|ml|iu)\b)"#,
                with: "e$1$2", options: .regularExpression)
            out = (out as NSString).replacingCharacters(in: span, with: inner)
        }
        return out
    }

    // MARK: - Parse

    /// Phrases that open a new, separate statement: allergen and facility notes.
    private static let statementStarts = try! NSRegularExpression(pattern:
        #"(?<![\p{L}])(contains|may contain|allergens?|allergy advice|manufactured (?:in|on)|produced (?:in|on)|processed (?:in|on)|made (?:in|on) a|made on equipment|packed (?:in|on)|peut contenir|contient|puede contener|contiene|kann spuren|mengandungi|mengandung|icerir|icerebilir)(?![\p{L}])"#)

    static func parse(_ normalized: String) -> [LabelItem] {
        // Statement starts become ";" so they split like any list boundary.
        let ns = normalized as NSString
        var text = normalized
        for m in statementStarts.matches(in: normalized, range: NSRange(location: 0, length: ns.length)).reversed() {
            text = (text as NSString).replacingCharacters(in: NSRange(location: m.range.location, length: 0), with: "; ")
        }

        var counter = 0
        struct Frame { var own = ""; var children: [LabelItem] = []; var items: [LabelItem] = [] }
        var stack = [Frame()]   // stack[0] is the root list

        func closeItem() {
            var f = stack.removeLast()
            let own = f.own.trimmingCharacters(in: CharacterSet(charactersIn: " .:-"))
            if !own.isEmpty || !f.children.isEmpty {
                f.items.append(LabelItem(own: own, children: f.children, index: counter))
                counter += 1
            }
            f.own = ""; f.children = []
            stack.append(f)
        }

        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            switch c {
            case "(":
                stack.append(Frame())
            case ")":
                guard stack.count > 1 else { break }   // stray ")" — ignore
                closeItem()
                let inner = stack.removeLast()
                stack[stack.count - 1].children += inner.items
            case ",", ";", ":", "•", "|", "،", "、", "；":
                closeItem()
            case "." where i + 1 >= chars.count || (chars[i + 1] == " " && !(i + 2 < chars.count && chars[i + 2].isNumber)):
                closeItem()
            default:
                stack[stack.count - 1].own.append(c)
            }
            i += 1
        }
        // Unclosed "(": fold the open frames back into their parents.
        while stack.count > 1 {
            closeItem()
            let inner = stack.removeLast()
            stack[stack.count - 1].children += inner.items
        }
        closeItem()
        return stack[0].items
    }

    /// Every item, depth-first in label order.
    static func flatten(_ items: [LabelItem]) -> [LabelItem] {
        items.flatMap { [$0] + flatten($0.children) }.sorted { $0.index < $1.index }
    }

    /// The phrase of `own` that contains `range`, cut at top-level conjunctions
    /// ("gelatin and soy lecithin" → "gelatin"). Used so a plant/synthetic word
    /// only resolves the ingredient it is actually attached to.
    static func phrase(in own: String, around range: Range<String.Index>) -> String {
        let pattern = #"\s(?:and/or|and|or|with|&|et|ou|y|o|und|oder|dan|atau|ve|veya|e|avec|con|mit)\s"#
        var lower = own.startIndex
        var upper = own.endIndex
        var searchStart = own.startIndex
        while let r = own.range(of: pattern, options: .regularExpression, range: searchStart..<own.endIndex) {
            if r.upperBound <= range.lowerBound { lower = r.upperBound }
            else if r.lowerBound >= range.upperBound { upper = r.lowerBound; break }
            searchStart = r.upperBound
        }
        return String(own[lower..<upper])
    }
}

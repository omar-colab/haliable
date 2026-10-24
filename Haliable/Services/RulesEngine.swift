//
//  RulesEngine.swift
//  Haliable
//
//  Created by Omar O on 5/30/26.
//

import Foundation
import Observation

// RulesEngine is the brain that decides: given a scanned product,
// which ingredients are flagged, and what's the overall verdict?
//
// Design principle (carried from the dossier): a false "Halal" is the
// unforgivable error. So anything we cannot positively confirm — unknown
// E-numbers, undisclosed sources, or a product with NO ingredient data —
// falls to "Questionable" (.doubtful), never silently to halal.
@Observable
final class RulesEngine {

    private(set) var rules: [IngredientRule] = []
    private(set) var eNumberMap: [String: String] = [:]

    // Fast lookup tables built ONCE when rules load.
    private var aliasIndex: [String: IngredientRule] = [:]
    private var eNumIndex: [String: IngredientRule] = [:]
    /// Every searchable term (normalized) → what it means.
    private var termIndex: [String: Target] = [:]
    private var latinTerms: NSRegularExpression?
    private var otherScriptTerms: NSRegularExpression?

    /// What a term on the label points at.
    private enum Target {
        case rule(IngredientRule)
        case eNumber(String)          // e.g. "E631" — graded through the E-number path
        case signal(Signal)           // a concern with no rule (meat, collagen, cheese)
    }

    init() {
        do {
            rules = try RulesLoader.loadRules()
            eNumberMap = try RulesLoader.loadENumbers()
            buildIndex()
        } catch {
            print("RulesEngine load failed: \(error)")
        }
    }

    /// Given rules instead of the bundled ones (tests: a failed load is `[]`).
    init(rules: [IngredientRule], eNumberMap: [String: String] = [:]) {
        self.rules = rules
        self.eNumberMap = eNumberMap
        if !rules.isEmpty { buildIndex() }
    }

    private func buildIndex() {
        for rule in rules {
            aliasIndex[rule.ingredient.lowercased()] = rule
            for alias in rule.aliases {
                aliasIndex[alias.lowercased()] = rule
            }
            if let eNumber = rule.eNumber?.uppercased() {
                eNumIndex[eNumber] = rule
            }
        }
        // Terms: rules first, so a rule always wins over a bare E-number name or a signal.
        func add(_ term: String, _ target: Target) {
            let key = IngredientParser.normalize(term)
            if !key.isEmpty, termIndex[key] == nil { termIndex[key] = target }
        }
        for rule in rules {
            add(rule.ingredient, .rule(rule))
            rule.aliases.forEach { add($0, .rule(rule)) }
        }
        for (name, code) in ENumberReference.nameToENumber { add(name, .eNumber(code)) }
        for signal in Signal.all { signal.terms.forEach { add($0, .signal(signal)) } }

        // One alternation per script, longest first so "pork lard" beats "pork".
        let keys = termIndex.keys.sorted { $0.count != $1.count ? $0.count > $1.count : $0 < $1 }
        let isLatin: (String) -> Bool = { $0.unicodeScalars.allSatisfy { $0.value < 0x0250 } }
        func alternation(_ ks: [String]) -> String {
            ks.map { k in
                let e = NSRegularExpression.escapedPattern(for: k)
                // Very short words must be whole words ("ham" not "hamburger",
                // "rum" not "rump"); a plural is allowed.
                // So must a few longer ones that start other words: "porc" in
                // Spanish "porción", "vino" in "vinous".
                return k.count <= 3 || Self.wholeWordOnly.contains(k) ? e + "(?:e?s)?(?![\\p{L}\\p{N}])" : e
            }.joined(separator: "|")
        }
        latinTerms = try? NSRegularExpression(
            pattern: "(?<![\\p{L}\\p{N}])(?:" + alternation(keys.filter(isLatin)) + ")")
        let other = keys.filter { !isLatin($0) }
        // Arabic prefixes (و, ال) attach to the word, so no word-start anchor here.
        otherScriptTerms = other.isEmpty ? nil : try? NSRegularExpression(pattern: alternation(other))
    }

    // MARK: - Evaluate

    // The main function: given a Product, return a full ProductVerdict.
    //
    // `standard` is the user's active strictness position. It rides along on every
    // MatchedIngredient so the per-ingredient verdict AND the roll-up reflect it
    // (e.g. Zabiha escalates unconfirmed meat to Haram). Defaults to the mainstream
    // baseline so existing callers and the unit tests are unaffected.
    func evaluate(product: Product, standard: HalalStandard = .general) -> ProductVerdict {
        let raw = product.rawIngredientsText ?? ""
        let labelItems = IngredientParser.flatten(IngredientParser.parse(IngredientParser.normalize(raw)))
        // Open Food Facts' English taxonomy tags ("en:pork-gelatin") read a label
        // in any language. They only fill in for what the text itself doesn't say.
        let tagText = product.ingredientTags
            .filter { $0.hasPrefix("en:") }
            .map { $0.dropFirst(3).replacingOccurrences(of: "-", with: " ") }
            .joined(separator: ", ")
        let tagItems = IngredientParser.flatten(IngredientParser.parse(IngredientParser.normalize(tagText)))
            .map { LabelItem(own: $0.own, children: $0.children, index: $0.index + 100_000, parentText: $0.parentText) }

        // Candidates per concern, grouped so one concern shows once. Label text
        // outranks tags, which outrank the bare OFF additive list.
        var fromText: [String: [MatchedIngredient]] = [:]
        var fromTags: [String: [MatchedIngredient]] = [:]
        var order: [String] = []
        func collect(_ items: [LabelItem], fromLabel: Bool) {
            for item in items {
                for (key, m) in matches(in: item, standard: standard) {
                    if fromText[key] == nil && fromTags[key] == nil { order.append(key) }
                    if fromLabel { fromText[key, default: []].append(m) } else { fromTags[key, default: []].append(m) }
                }
            }
        }
        collect(labelItems, fromLabel: true)
        collect(tagItems, fromLabel: false)

        // STEP 1: structured E-number list from Open Food Facts. Used for any
        // additive the label text didn't already name.
        var fromOFF: [String: MatchedIngredient] = [:]
        for code in Self.normalizedENumbers(product.additivesENumbers) {
            let key = key(forENumber: code)
            guard fromText[key] == nil, fromTags[key] == nil, fromOFF[key] == nil else { continue }
            let located = locate(code: code, in: labelItems + tagItems)
            fromOFF[key] = eNumberMatch(code, item: located?.item, range: located?.range, standard: standard)
            order.append(key)
        }

        // Worst grade wins inside a group: "gelatin, …, gelatin (pork)" is pork.
        var matched: [MatchedIngredient] = order.compactMap { key in
            let group = fromText[key] ?? fromTags[key] ?? fromOFF[key].map { [$0] } ?? []
            return group.min { a, b in
                a.grade != b.grade ? a.grade > b.grade : a.labelIndex < b.labelIndex
            }
        }

        // STEP 2: a label we can't read is not a clean label.
        let letters = raw.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        let latin = letters.filter { $0.value < 0x0250 }.count
        if letters.count >= 8, Double(latin) / Double(letters.count) < 0.5, tagItems.isEmpty {
            matched.append(MatchedIngredient(
                originalText: "Ingredients in an unsupported script",
                matchedRule: nil, standard: standard,
                note: "The ingredients are written in a script we can't check yet, so we couldn't confirm anything on this label. Check an English label or ask the manufacturer.",
                labelText: String(raw.prefix(120))))
        }

        // STEP 2b: rules that failed to load can't check anything — never let
        // that read as a clean label.
        if rules.isEmpty || latinTerms == nil {
            matched.append(MatchedIngredient(
                originalText: "Ingredient rules unavailable",
                matchedRule: nil, standard: standard,
                note: "Haliable's ingredient rules didn't load, so nothing on this label could be checked. Restart the app; if this stays, reinstall it."))
        }

        // A nutrition panel or marketing line where the list should be: what we
        // checked isn't the whole label, so it can't come out clean.
        if Self.looksIncomplete(raw) {
            matched.append(MatchedIngredient(
                originalText: "Ingredient list looks incomplete",
                matchedRule: nil, standard: standard,
                note: "The ingredient text we have for this product looks like part of the nutrition panel or packaging, not the full list, so we couldn't confirm it. Check the package label.",
                labelText: String(raw.prefix(120))))
        }

        // STEP 3: SAFETY NET — if we had nothing to inspect, we cannot claim halal.
        let hasIngredientData =
            !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !product.additivesENumbers.isEmpty
        if !hasIngredientData {
            matched.append(MatchedIngredient(
                originalText: "No ingredient information available",
                matchedRule: nil,   // nil rule → Questionable, with an explanation
                standard: standard,
                note: "This product has no ingredient list in the databases we check, so nothing on it could be confirmed. Read the package label, or ask a scholar below."
            ))
        }

        // STEP 4: roll up to one overall GRADE using worst-case logic, then apply
        // the certification overlay.
        let worstGrade = matched.map(\.grade).max() ?? .halal

        // Certification overlay: when a certifier whose satisfaction of the active
        // standard is CITED is on the label, it has vetted the ingredients — so
        // upgrade a NON-haram product to Halal. Gated by the SAME citation rule as
        // the badge (Citation Protocol §8): an uncited satisfaction claim can't
        // produce a confident "Halal" in the app's own voice. It never upgrades
        // past a haram ingredient — a "halal" claim over pork/khamr is contradictory.
        let overallGrade: GradeLevel
        if worstGrade < .haram,
           let body = CertificationBody.detect(in: product.labels),
           SatisfactionClaim.make(body: body, standard: standard).isClearedSatisfaction {
            overallGrade = .halal
        } else {
            overallGrade = worstGrade
        }

        return ProductVerdict(product: product, matched: matched, overallGrade: overallGrade)
    }

    // MARK: - Matching one label item

    /// Every concern named in one label item's own words, keyed by concern.
    private func matches(in item: LabelItem, standard: HalalStandard) -> [(String, MatchedIngredient)] {
        let own = item.own
        guard !own.isEmpty else { return [] }
        let masked = Self.maskedRanges(in: own)
        var hits: [(Range<String.Index>, Target)] = []

        for re in [latinTerms, otherScriptTerms].compactMap({ $0 }) {
            for m in re.matches(in: own, range: NSRange(own.startIndex..., in: own)) {
                guard let r = Range(m.range, in: own), !masked.contains(where: { $0.contains(r.lowerBound) }) else { continue }
                let word = String(own[r])
                let target = termIndex[word]
                    ?? termIndex[String(word.dropLast(word.hasSuffix("es") ? 2 : 1))]
                if let target { hits.append((r, target)) }
            }
        }
        for (re, ruleID) in Self.patternAliases {
            guard let rule = rules.first(where: { $0.id == ruleID }) else { continue }
            for m in re.matches(in: own, range: NSRange(own.startIndex..., in: own)) {
                if let r = Range(m.range, in: own) { hits.append((r, .rule(rule))) }
            }
        }
        for m in Self.eCode.matches(in: own, range: NSRange(own.startIndex..., in: own)) {
            if let r = Range(m.range, in: own) { hits.append((r, .eNumber(String(own[r]).uppercased()))) }
        }

        // A signal adds nothing when a rule already covers the item ("beef gelatin"
        // is the gelatin rule with a beef origin, not a second meat flag).
        let hasRule = hits.contains { if case .rule = $0.1 { return true } else { return false } }

        var out: [(String, MatchedIngredient)] = []
        for (range, target) in hits.sorted(by: { $0.0.lowerBound < $1.0.lowerBound }) {
            switch target {
            case .rule(let rule):
                let (origin, context) = origin(of: range, in: item)
                out.append((rule.id, MatchedIngredient(
                    originalText: context, matchedRule: rule, standard: standard,
                    originAssumption: origin, labelText: item.labelText, labelIndex: item.index)))
            case .eNumber(let code):
                out.append((key(forENumber: code), eNumberMatch(code, item: item, range: range, standard: standard)))
            case .signal(let signal):
                if hasRule { continue }
                if signal.onlyWithoutDetail && !item.children.isEmpty { continue }
                let (origin, context) = origin(of: range, in: item)
                out.append(("signal:" + signal.id, MatchedIngredient(
                    originalText: context, matchedRule: nil, standard: standard,
                    originAssumption: origin, note: signal.note,
                    labelText: item.labelText, labelIndex: item.index, categoryHint: signal.category)))
            }
        }
        return out
    }

    /// Origin for a term found at `range` in `item`, plus the text it was read from.
    /// Animal qualifiers count from anywhere the label describes the item (strict);
    /// plant/synthetic ones only from the term's own phrase and its parentheses.
    private func origin(of range: Range<String.Index>, in item: LabelItem) -> (Origin, String) {
        let phrase = IngredientParser.phrase(in: item.own, around: range)
        let ownPhraseOnly = phrase.count < item.own.count
        let context = ownPhraseOnly || item.children.isEmpty
            ? phrase : phrase + " (" + item.descendantsText + ")"
        let origin = ENumberReference.animalOrigin(from: item.fullText)
            ?? ENumberReference.nonAnimalOrigin(from: context)
            ?? .unspecified
        return (origin, context.trimmingCharacters(in: .whitespaces))
    }

    private func key(forENumber code: String) -> String {
        rule(forENumber: code)?.id ?? code
    }

    /// The rule for a code: its own, else one whose alias is the code's name
    /// (E428 "gelatine" is the gelatin rule). Names in e-numbers.json must be
    /// specific: E472 is "esters of …", not E471's name.
    private func rule(forENumber code: String) -> IngredientRule? {
        eNumIndex[code] ?? aliasIndex[(eNumberMap[code] ?? "").lowercased()]
    }

    private func eNumberMatch(_ code: String, item: LabelItem?, range: Range<String.Index>?,
                              standard: HalalStandard) -> MatchedIngredient {
        let name = eNumberMap[code]
        let rule = rule(forENumber: code)
        var origin = Origin.unspecified
        if let item, let range { origin = self.origin(of: range, in: item).0 }
        let note: String? = rule != nil ? nil : name.map {
            "\(code) (\($0)) is a recognised additive, but no published halal source in our database covers it yet, so its origin can't be confirmed."
        } ?? "\(code) isn't in our additive list, so we couldn't check where it comes from."
        return MatchedIngredient(
            originalText: rule?.ingredient ?? name.map { "\(code) (\($0))" } ?? code,
            matchedRule: rule, standard: standard, originAssumption: origin,
            note: note, labelText: item?.labelText, labelIndex: item?.index ?? Int.max)
    }

    /// The first label item naming `code` (as "e471" or by its additive name).
    private func locate(code: String, in items: [LabelItem]) -> (item: LabelItem, range: Range<String.Index>)? {
        var names = [code.lowercased()]
        if let n = eNumberMap[code] { names.append(IngredientParser.normalize(n)) }
        if let rule = eNumIndex[code] { names += rule.aliases.map(IngredientParser.normalize) }
        // One pattern per code, compiled once (not once per name × item).
        guard let re = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}])(?:"
            + names.filter { !$0.isEmpty }.sorted { $0.count > $1.count }
                .map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") + ")")
        else { return nil }
        for item in items {
            if let m = re.firstMatch(in: item.own, range: NSRange(item.own.startIndex..., in: item.own)),
               let r = Range(m.range, in: item.own) {
                return (item, r)
            }
        }
        return nil
    }

    // MARK: - Static tables

    /// Text that isn't a full ingredient list: it carries nutrition-panel
    /// words, or it is one long run of words with no list separators.
    /// ponytail: keyword heuristic; OCR'd panels in other languages slip past.
    static func looksIncomplete(_ raw: String) -> Bool {
        let t = raw.lowercased()
        if t.range(of: "calories|daily value|valor diario|serving size|nutrition facts|per serving|amount per",
                   options: .regularExpression) != nil { return true }
        let items = t.split(whereSeparator: { ",;".contains($0) }).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return items.count < 2 && t.split(separator: " ").count > 6
    }

    private static let wholeWordOnly: Set<String> = ["porc", "vino", "babi", "sake", "arak", "bira", "lager"]

    private static let eCode = try! NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}])e\\d{3,4}(?![\\p{L}\\p{N}])")

    /// Wording that names a concern without containing it. A masked span can only
    /// STOP a match — it never makes anything halal by itself.
    private static let masks = try! NSRegularExpression(pattern: [
        "(?:alcohol|alcool|alkohol|pork|porcine|gelatine?|lard|animal|meat)[ -]?free",
        "(?:no|non|without|free from|sans|sin|ohne|bebas|tanpa)[ -](?:added )?(?:alcohol(?:ic)?|alcool|alkohol|pork|porcine|gelatine?|lard|animal|meat)",
        // German "enthält kein Schweinefett"; Turkish "hiçbir çeşidinde alkol ve domuz
        // yağı kullanılmamaktadır" (the negation opens the clause, runs to its end).
        "kein(?:e|en|er)? (?:alkohol|schweine\\p{L}*|gelatine|tierische\\p{L}*)",
        // "Our products do not contain any alcohol or pork based ingredients."
        "(?:do(?:es)? not|does?n.?t|never|will not) contain(?:s)?(?: any)?[^.;]*|contains? no [^.;]*",
        "(?:لا [يت]حتوي|خال[يى]?[ةه]? من|بدون)[^.;،]*",   // Arabic "doesn't contain / free of / without"
        "h[iı]cbir[^.,;]*", "(?:alkol|domuz)[^.;]*(?:yoktur|kullan[iı]lmamaktad[iı]r|kat[iı]lmam[iı]st[iı]r|i[cç]ermez)", "huhnere[iı]\\p{L}*",
        "non-?alcoholic", "sugar alcohols?", "liquorice", "root beer", "meatless", "babies", "cheese cultures?",
        "coconut meat", "(?:chocolate|cocoa|cacao) liquor", "bourbon vanilla", "vanill\\p{L}*(?: \\p{L}+)? bourbon", "porcini", "weinstein", "weinsaure", "weintraube", "beefsteak tomato", "lamb's lettuce",
        "goat'?s? (?:milk|cheese|yogh?urt|butter)", "chicken eggs?", "duck eggs?",
        "(?:product of|made in|produced in|origin:?) turkey",
        // "turkey bacon" is turkey, not pork: only the word "bacon"/"ham" is masked,
        // the turkey itself is still flagged as meat.
        "(?<=turkey |chicken |beef )(?:bacon|ham)",
    ].joined(separator: "|"))

    private static func maskedRanges(in text: String) -> [Range<String.Index>] {
        masks.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range, in: text) }
    }

    /// Wording that can't be a fixed alias: "natural cherry flavor", "natural
    /// vanilla flavouring".
    private static let patternAliases: [(NSRegularExpression, String)] = [
        (try! NSRegularExpression(pattern: "(?<![\\p{L}])natural (?:[\\p{L}-]+ ){1,3}flavou?r"), "natural-flavors"),
    ]

    // MARK: - E-number helpers

    /// OFF tags sub-variants ("en:e322i", "en:e472e", "en:e150d") that the rule,
    /// E-number and matrix tables key on the base code ("E322"). Without this a
    /// gum label's soy lecithin arrived twice — once as E322 (resolved, halal) and
    /// once as "E322I", unknown and therefore Questionable. Normalizes to the base
    /// code, upper-cased, and drops duplicates while keeping label order. Anything
    /// that isn't an E-number shape passes through untouched.
    static func normalizedENumbers(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for tag in raw {
            let code = normalizeENumber(tag)
            if seen.insert(code).inserted { out.append(code) }
        }
        return out
    }

    static func normalizeENumber(_ tag: String) -> String {
        var t = tag.trimmingCharacters(in: .whitespaces).uppercased()
        if let colon = t.lastIndex(of: ":") { t = String(t[t.index(after: colon)...]) }
        guard let r = t.range(of: #"^E\d{3,4}"#, options: .regularExpression) else { return t }
        return String(t[r])
    }

    /// True when `term` appears in `text` starting at a word boundary. A bare
    /// substring check let the alias "rum" fire inside French "lactoserum" (whey),
    /// grading Nutella haram for wine. Only the START is anchored, so prefix forms
    /// like "lardons" or "porkfat" still match — this can't open a false-halal path.
    static func mentions(_ term: String, in text: String) -> Bool {
        let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: term)
        return text.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Signals

/// A concern with no rule of its own. It is flagged with an honest note and
/// graded by the matrix's category fallback (meat → the cited meat row; collagen
/// → the gelatin row; anything else → the rule baseline, Questionable). Signals
/// only ever ADD a flag; they never clear one.
struct Signal {
    let id: String
    let terms: [String]
    let note: String
    /// The matrix category it grades under (nil → rule baseline, Questionable).
    var category: IngredientCategory? = nil
    /// Only flag when the label gives no breakdown, e.g. bare "cheese" but not
    /// "cheese (milk, cultures, salt, enzymes)" — the enzymes line is matched itself.
    var onlyWithoutDetail = false

    static let all: [Signal] = [
        Signal(id: "meat", terms: [
            "chicken", "beef", "lamb", "mutton", "veal", "turkey", "duck", "goat", "venison",
            "poultry", "meat", "tallow", "suet", "animal fat", "animal shortening", "bone broth",
            "pepperoni", "salami", "chorizo", "sausage", "hot dog", "gammon",
            "poulet", "boeuf", "viande", "pollo", "carne", "ayam", "daging", "tavuk", "sigir eti",
            "huhn",
        ], note: "Meat or a meat-derived ingredient. It is halal only when the animal was slaughtered Islamically, and this label doesn't say how it was slaughtered.",
           category: .meat),
        Signal(id: "vitamin-d3", terms: ["vitamin d3", "vitamin d-3", "cholecalciferol"],
               note: "Vitamin D3 is usually made from lanolin (sheep's wool), sometimes from fish oil or lichen, and the label doesn't say which."),
        Signal(id: "collagen", terms: ["collagen", "kolagen", "collageen"],
               note: "Collagen is made from animal skin or bone, or from fish, and the label doesn't say which.",
               category: .gelatin),
        Signal(id: "cheese", terms: ["cheese", "fromage", "queso", "keju", "peynir", "kase"],
               note: "Cheese is usually set with enzymes (rennet) that can come from an animal, and this label doesn't say which kind was used.",
               onlyWithoutDetail: true),
    ]
}

//
//  CertifiedBrandStore.swift
//  Haliable
//
//  Loads the bundled `certified-brands.json` — a curated, PARTIAL directory of
//  consumer food brands whose products are halal-certified by a named body. It
//  exists to RECOVER a certifier when Open Food Facts has no `labels_tags` for
//  the product (which is the common case): if the scanned product's brand matches
//  a known certified brand, we can still surface "this brand is listed as certified
//  by <body>".
//
//  Integrity boundary (carried from the dossier): a brand match is WEAKER evidence
//  than a per-product label — it says nothing about the specific SKU, and nothing
//  about whether the body meets the user's standard. So callers must (a) flag it
//  as brand-level / "verify on packaging", and (b) still route the standard claim
//  through the SAME citation gate (SatisfactionClaim) as everything else. This
//  store only answers "which body lists this brand?" — never a fiqh ruling.
//
//  A missing/unparseable file degrades safely to empty (no brand ever matches).
//

import Foundation

/// One brand entry from certified-brands.json.
struct CertifiedBrand: Codable, Hashable {
    let name: String
    let aliases: [String]?
    let certifier: String        // CertificationBody.rawValue, e.g. "hfsaa"
    let region: String?
    let category: String?
}

/// Top-level shape of certified-brands.json.
struct CertifiedBrandFile: Codable, Hashable {
    let version: Int
    let note: String?
    let brands: [CertifiedBrand]
}

/// Loads + indexes certified-brands.json. `shared` is the production instance;
/// it is a `var` ONLY so tests may inject a fixture — production never reassigns.
final class CertifiedBrandStore {

    static var shared = CertifiedBrandStore()

    /// Normalized brand key → body. Built from each brand's name + aliases.
    private let byBrand: [String: CertificationBody]

    /// Production init — load from the bundle, degrade to empty on any failure.
    init() {
        self.byBrand = Self.index(Self.loadFromBundle()?.brands ?? [])
    }

    /// Test/explicit init.
    init(brands: [CertifiedBrand]) {
        self.byBrand = Self.index(brands)
    }

    // MARK: - Lookup

    /// The certifying body that lists this product's brand, or nil.
    ///
    /// Open Food Facts often returns several comma-separated brands
    /// (e.g. "Saffron Road, Crescent"); USDA returns the brand owner. We test the
    /// whole string and each comma-separated piece against the known-brand index,
    /// matching on a normalized, word-boundary-safe basis so "Green" can't
    /// masquerade as "Greener Pastures".
    func certifier(forBrand brand: String?) -> CertificationBody? {
        guard let brand, !brand.isEmpty else { return nil }
        let candidates = ([brand] + brand.split(separator: ",").map(String.init))
            .map(Self.normalize)
            .filter { !$0.isEmpty }
        for candidate in candidates {
            // Exact normalized hit first (cheapest, strongest).
            if let body = byBrand[candidate] { return body }
            // Otherwise see if a known brand appears as a leading token of the
            // candidate (e.g. "saffron road organic" → "saffron road").
            for (known, body) in byBrand where Self.isBrandPrefix(known, of: candidate) {
                return body
            }
        }
        return nil
    }

    var brandCount: Int { byBrand.count }

    // MARK: - Indexing & normalization

    private static func index(_ brands: [CertifiedBrand]) -> [String: CertificationBody] {
        var out: [String: CertificationBody] = [:]
        for brand in brands {
            guard let body = CertificationBody(rawValue: brand.certifier) else { continue }
            for label in [brand.name] + (brand.aliases ?? []) {
                let key = normalize(label)
                if !key.isEmpty { out[key] = body }
            }
        }
        return out
    }

    /// Lowercase, strip punctuation to spaces, drop generic corporate suffixes,
    /// and collapse whitespace — so "Pik-Nik Foods, USA" and "pik nik" align.
    static func normalize(_ raw: String) -> String {
        let lowered = raw.lowercased()
        let cleaned = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        var tokens = String(cleaned).split(separator: " ").map(String.init)
        let noise: Set<String> = ["inc", "llc", "co", "ltd", "corp", "company",
                                  "usa", "foods", "food", "packing", "enterprises",
                                  "the", "brand", "brands"]
        tokens.removeAll { noise.contains($0) }
        return tokens.joined(separator: " ")
    }

    /// True when `known` matches `candidate` exactly or as a whole leading phrase
    /// (token boundary), guarding against short-substring false positives.
    private static func isBrandPrefix(_ known: String, of candidate: String) -> Bool {
        guard known.count >= 4 else { return known == candidate }
        if known == candidate { return true }
        return candidate == known || candidate.hasPrefix(known + " ")
    }

    // MARK: - Loading

    static func decode(_ data: Data) -> CertifiedBrandFile? {
        try? JSONDecoder().decode(CertifiedBrandFile.self, from: data)
    }

    private static func loadFromBundle() -> CertifiedBrandFile? {
        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: "certified-brands", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let file = decode(data) {
                return file
            }
        }
        return nil
    }
}

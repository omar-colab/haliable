//
//  USDAFoodDataService.swift
//  Haliable
//
//  Created by Omar O on 6/2/26.
//

import Foundation

// USDA FoodData Central — our FALLBACK when Open Food Facts
// doesn't have a product. USDA's Branded Foods dataset has
// ~1.5M US grocery items with real ingredient statements.
final class USDAFoodDataService: ProductLookupSource {

    // The USDA key from Info.plist (← git-ignored Secrets.xcconfig). There is NO
    // hardcoded fallback: a halal verdict must never quietly depend on a shared
    // public demo key. When the key is absent the USDA tier disables itself
    // (fetchProduct throws `.configurationMissing`) and the lookup chain skips to
    // Open Food Facts — see ProductLookupService.
    static let apiKey: String? = {
        let k = Bundle.main.object(forInfoDictionaryKey: "USDA_API_KEY") as? String
        guard let k, !k.isEmpty, k != "PASTE_YOUR_USDA_KEY_HERE" else { return nil }
        return k
    }()

    /// Whether the USDA tier is usable (a real key is present).
    static var isConfigured: Bool { apiKey != nil }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // USDA's search response shape. We only decode the fields we use.
    private struct USDASearchResponse: Codable {
        let foods: [USDAFood]
    }

    private struct USDAFood: Codable {
        let description: String?
        let brandOwner: String?
        let gtinUpc: String?           // the barcode, as a string
        let ingredients: String?       // the full ingredient statement
    }

    /// USDA pads codes inconsistently (UPC-A vs GTIN-14), so compare without leading zeros.
    static func sameCode(_ gtin: String, _ barcode: String) -> Bool {
        let strip = { (s: String) in s.drop { $0 == "0" } }
        return !strip(barcode).isEmpty && strip(gtin) == strip(barcode)
    }

    // Given a barcode, search USDA Branded Foods and return a Product.
    // Same async throws shape as OpenFoodFactsService, so callers
    // treat both services identically.
    func fetchProduct(barcode: String) async throws -> Product {
        // No key → this tier is unavailable. We throw a typed error instead of
        // quietly using a shared demo key; the lookup chain skips to OFF.
        guard let apiKey = Self.apiKey else {
            throw OFFError.configurationMissing(
                "USDA lookups need a USDA_API_KEY in Secrets.xcconfig — get a free key at https://fdc.nal.usda.gov/api-key-signup.html")
        }

        // Build the search URL. We query by the barcode and restrict
        // to the Branded dataset (the one with real grocery products).
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: barcode),
            URLQueryItem(name: "dataType", value: "Branded"),
            URLQueryItem(name: "pageSize", value: "5"),
            URLQueryItem(name: "api_key", value: apiKey)
        ]

        guard let url = components.url else {
            throw OFFError.networkFailure(underlying: URLError(.badURL))
        }

        // Network call with timeout + retry/backoff (429/5xx/transient) handled
        // centrally; terminal failures arrive as typed OFFErrors.
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, http) = try await HTTPRetry.data(for: request, session: session)

        if http.statusCode != 200 {
            throw OFFError.badStatus(http.statusCode)
        }

        // Decode the search results.
        let decoded: USDASearchResponse
        do {
            decoded = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        } catch {
            throw OFFError.decoding(error)
        }

        // USDA search is full-text, so the top hit for a barcode with no exact
        // match is some OTHER product. Grading its ingredients under this
        // barcode can say "halal" for the wrong food, so an exact GTIN match is
        // required; anything else is not-found here and the chain moves to OFF.
        guard let food = decoded.foods.first(where: { $0.gtinUpc.map { Self.sameCode($0, barcode) } ?? false }) else {
            throw OFFError.productNotFound
        }

        // Translate USDA's shape into our clean Product.
        // USDA gives one ingredients STRING, not pre-tagged E-numbers,
        // so additivesENumbers is empty — the RulesEngine will still
        // catch E-numbers and ingredient names via its text scan.
        return Product(
            id: food.gtinUpc ?? barcode,
            name: food.description ?? "Unknown product",
            brand: food.brandOwner,
            rawIngredientsText: food.ingredients,
            additivesENumbers: []
        )
    }
}

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
final class USDAFoodDataService {

    // Read from Info.plist (← Secrets.xcconfig). Falls back to USDA's public
    // demo key so the app still builds before you add your own.
    private let apiKey: String = {
        let k = Bundle.main.object(forInfoDictionaryKey: "USDA_API_KEY") as? String
        return (k?.isEmpty == false && k != "PASTE_YOUR_USDA_KEY_HERE") ? k! : "DEMO_KEY"
    }()
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

    // Given a barcode, search USDA Branded Foods and return a Product.
    // Same async throws shape as OpenFoodFactsService, so callers
    // treat both services identically.
    func fetchProduct(barcode: String) async throws -> Product {
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

        // Do the network call.
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw OFFError.networkFailure(underlying: error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw OFFError.badStatus(http.statusCode)
        }

        // Decode the search results.
        let decoded: USDASearchResponse
        do {
            decoded = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        } catch {
            throw OFFError.decoding(error)
        }

        // USDA search can return loose matches, so find the food whose
        // gtinUpc actually matches the barcode we scanned. If none match
        // exactly, fall back to the first result (USDA's best guess).
        let normalized = barcode.count == 12 ? "0" + barcode : barcode
        let exact = decoded.foods.first { food in
            guard let gtin = food.gtinUpc else { return false }
            // USDA pads codes inconsistently; compare ignoring leading zeros.
            return gtin.hasSuffix(barcode) || gtin.hasSuffix(normalized)
        }
        guard let food = exact ?? decoded.foods.first else {
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

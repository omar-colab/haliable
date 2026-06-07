//
//  OpenFoodFactsService.swift
//  Haliable
//
//  Created by Omar O on 5/30/26.
//

import Foundation

// The ways a product lookup can fail.
// Each case has a different recovery — defining them as an enum
// forces every caller to handle each one specifically.
enum OFFError: Error, LocalizedError {
    case productNotFound
    case networkFailure(underlying: Error)
    case decoding(Error)
    case badStatus(Int)

    // A human-readable message for each error, used by SwiftUI views later.
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "This product isn't in the Open Food Facts database yet."
        case .networkFailure(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .decoding:
            return "Couldn't read the product data."
        case .badStatus(let code):
            return "Server returned status \(code)."
        }
    }
}

// Mirrors the JSON shape Open Food Facts returns at /api/v2/product/{barcode}.json
// We decode INTO this, then translate it into our clean Product type.
struct OFFResponse: Codable {
    let code: String
    let status: Int               // 1 = found, 0 = not found
    let product: OFFProduct?

    enum CodingKeys: String, CodingKey {
        case code, status, product
    }
}

struct OFFProduct: Codable {
    let productName: String?
    let brands: String?
    let ingredientsText: String?
    let additivesTags: [String]?  // e.g. ["en:e120", "en:e441"]

    enum CodingKeys: String, CodingKey {
        case brands
        case productName = "product_name"
        case ingredientsText = "ingredients_text"
        case additivesTags = "additives_tags"
    }
}

// OpenFoodFactsService: handed a barcode, returns a Product (or throws).
final class OpenFoodFactsService {

    // CHANGE THIS to a real contact email before TestFlight.
    private let userAgent = "Haliable/0.1 (contact@haliable.app)"
    private let session: URLSession

    // Allows injecting a custom URLSession for testing later.
    // Defaults to .shared, which is fine for normal use.
    init(session: URLSession = .shared) {
        self.session = session
    }

    // The main function. 'async' means it can pause while waiting
    // for the network. 'throws' means it can fail. The caller will
    // write 'try await offService.fetchProduct(barcode:)'.
    func fetchProduct(barcode: String) async throws -> Product {

        // OFF stores 12-digit UPC-A codes as 13-digit EAN-13 by
        // prepending a zero. Normalize before looking up.
        let normalized = barcode.count == 12 ? "0" + barcode : barcode

        guard let url = URL(string:
            "https://world.openfoodfacts.org/api/v2/product/\(normalized).json"
        ) else {
            throw OFFError.networkFailure(underlying: URLError(.badURL))
        }

        // Build the request and set the User-Agent header.
        // OFF asks every client to identify itself; without it
        // your requests may be throttled or blocked.
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        // Actually do the network call. This is the line that pauses.
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OFFError.networkFailure(underlying: error)
        }

        // Check the HTTP status code. 200 = OK; anything else = problem.
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw OFFError.badStatus(http.statusCode)
        }

        // Decode the JSON into our OFFResponse shape.
        let decoded: OFFResponse
        do {
            decoded = try JSONDecoder().decode(OFFResponse.self, from: data)
        } catch {
            throw OFFError.decoding(error)
        }

        // OFF returns status:0 when the product simply isn't in the DB.
        // That's not a network error — it's a "we don't know this product"
        // signal, which we treat as its own error type.
        guard decoded.status == 1, let offProduct = decoded.product else {
            throw OFFError.productNotFound
        }

        // Extract the E-numbers from OFF's additives_tags array.
        // OFF tags look like "en:e120" — we strip "en:" and uppercase.
        let eNumbers = (offProduct.additivesTags ?? []).map {
            $0.replacingOccurrences(of: "en:", with: "").uppercased()
        }

        // Translate from OFF's shape to our app's clean Product type.
        // From here on, the rest of the app never sees OFF's structure —
        // it just sees a Product. This is called a "translation layer."
        return Product(
            id: decoded.code,
            name: offProduct.productName ?? "Unknown product",
            brand: offProduct.brands,
            rawIngredientsText: offProduct.ingredientsText,
            additivesENumbers: eNumbers
        )
    }
}

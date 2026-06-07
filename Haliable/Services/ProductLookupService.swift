//
//  ProductLookupService.swift
//  Haliable
//
//  Created by Omar O on 6/2/26.
//

import Foundation

// Coordinates the two data sources. Try Open Food Facts first
// (richer additive tagging); if the product isn't there, fall
// back to USDA (better US coverage). This is the single entry
// point the rest of the app uses — it never calls OFF or USDA
// directly, only this.
final class ProductLookupService {

    private let off = OpenFoodFactsService()
    private let usda = USDAFoodDataService()

    func fetchProduct(barcode: String) async throws -> Product {
        do {
            // First choice: Open Food Facts.
            return try await off.fetchProduct(barcode: barcode)
        } catch OFFError.productNotFound {
            // OFF simply didn't have it — try USDA before giving up.
            // Note: we ONLY fall through on productNotFound. A network
            // error, by contrast, should surface, not be masked.
            return try await usda.fetchProduct(barcode: barcode)
        }
        // Any other error (network, decoding, badStatus) is NOT caught
        // here — it propagates up so the UI can show the right message.
    }
}

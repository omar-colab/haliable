//
//  ProductLookupService.swift
//  Haliable
//
//  The single entry point the app uses to turn a barcode into a Product. It owns
//  an EXPLICIT, predictable fallback chain and degrades the same way every time:
//
//      USDA  →  Open Food Facts  →  on-device cache (offline)
//
//  • USDA is tried first (per the hardening spec) but skips itself instantly when
//    no API key is configured, so no wasted request.
//  • A "not found" on one source falls through to the next.
//  • A CONNECTIVITY failure on the first source still tries the second, and if
//    both are unreachable the cache answers with the last-known result.
//  • If nothing resolves, a typed OFFError propagates so the UI shows a clear
//    state — never a crash, never a silent empty.
//
//  The in-house ENumberReference remains the GRADING fallback (RulesEngine /
//  GradeMatrix already enrich ingredient text with it); it can't synthesize a
//  product from a barcode, so it is not a lookup tier here.
//

import Foundation

/// A single product source (USDA, Open Food Facts, or a test fake).
protocol ProductLookupSource {
    func fetchProduct(barcode: String) async throws -> Product
}

final class ProductLookupService {

    private let usda: ProductLookupSource
    private let off: ProductLookupSource

    /// Defaults wire the real sources; tests inject fakes.
    init(usda: ProductLookupSource = USDAFoodDataService(),
         off: ProductLookupSource = OpenFoodFactsService()) {
        self.usda = usda
        self.off = off
    }

    /// Resolve a barcode through the chain, caching successes and falling back to
    /// the cache only when the network is unavailable.
    func fetchProduct(barcode: String, cache: ProductCaching? = nil) async throws -> Product {
        do {
            let product = try await resolveOnline(barcode: barcode)
            await cache?.store(product)
            return product
        } catch let error as OFFError {
            // Connectivity failure → answer from the last-known cache if we can.
            switch error {
            case .offline, .networkFailure:
                if let hit = await cache?.cached(barcode: barcode) { return hit }
            default:
                break
            }
            throw error
        }
    }

    // MARK: - The chain

    private func resolveOnline(barcode: String) async throws -> Product {
        var connectivityError: OFFError?

        // Tier 1 — USDA (skips itself via .configurationMissing when no key).
        do {
            return try await usda.fetchProduct(barcode: barcode)
        } catch let e as OFFError {
            switch e {
            case .productNotFound, .configurationMissing:
                break                                   // fall through to OFF
            case .offline, .networkFailure, .rateLimited, .badStatus, .decoding:
                connectivityError = e                   // remember; OFF may still work
            }
        }

        // Tier 2 — Open Food Facts.
        do {
            return try await off.fetchProduct(barcode: barcode)
        } catch OFFError.productNotFound {
            // Neither source had it. If USDA failed for a connectivity reason,
            // surface THAT (so the cache tier can answer); otherwise it's a
            // genuine not-found.
            if let connectivityError { throw connectivityError }
            throw OFFError.productNotFound
        }
    }
}

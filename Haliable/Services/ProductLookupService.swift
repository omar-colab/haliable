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
        // The scanner also reads QR / Code 128, which can carry any text. Only a
        // plain code goes into the OFF URL path — "../" or "?" never does.
        guard Self.isLookupable(barcode) else { throw OFFError.productNotFound }
        do {
            let product: Product
            do {
                product = try await resolveOnline(barcode: barcode)
            } catch OFFError.productNotFound {
                // Small packs (cans, candy) carry 8-digit UPC-E; USDA and many OFF
                // entries only know the full UPC-A. Try that before giving up.
                guard let full = Self.upcAFromUPCE(barcode) else { throw OFFError.productNotFound }
                product = try await resolveOnline(barcode: full)
            }
            cache?.store(product)
            return product
        } catch let error as OFFError {
            // Connectivity failure → answer from the last-known cache if we can.
            switch error {
            case .offline, .networkFailure:
                if let hit = cache?.cached(barcode: barcode) { return hit }
            default:
                break
            }
            throw error
        }
    }

    /// UPC-E (8 digits, number system 0 or 1) → its 12-digit UPC-A, or nil when
    /// the code isn't a valid UPC-E (e.g. an EAN-8 whose check digit won't fit).
    static func upcAFromUPCE(_ code: String) -> String? {
        let d = code.compactMap(\.wholeNumberValue)
        guard code.count == 8, d.count == 8, d[0] <= 1 else { return nil }
        let s = Array(d[1...6])
        let body: [Int]
        switch s[5] {
        case 0...2: body = [s[0], s[1], s[5], 0, 0, 0, 0, s[2], s[3], s[4]]
        case 3:     body = [s[0], s[1], s[2], 0, 0, 0, 0, 0, s[3], s[4]]
        case 4:     body = [s[0], s[1], s[2], s[3], 0, 0, 0, 0, 0, s[4]]
        default:    body = [s[0], s[1], s[2], s[3], s[4], 0, 0, 0, 0, s[5]]
        }
        let eleven = [d[0]] + body
        let odd = stride(from: 0, to: 11, by: 2).map { eleven[$0] }.reduce(0, +)
        let even = stride(from: 1, to: 11, by: 2).map { eleven[$0] }.reduce(0, +)
        guard (10 - (odd * 3 + even) % 10) % 10 == d[7] else { return nil }
        return (eleven + [d[7]]).map(String.init).joined()
    }

    static func isLookupable(_ code: String) -> Bool {
        code.range(of: #"^[0-9A-Za-z-]{1,32}$"#, options: .regularExpression) != nil
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

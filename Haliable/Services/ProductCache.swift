//
//  ProductCache.swift
//  Haliable
//
//  A small persistent cache of resolved products, keyed by barcode, so a product
//  scanned before still resolves when the network is unavailable. It is the LAST
//  tier of the lookup chain (USDA → Open Food Facts → cache): the online sources
//  are always tried first for freshness, and the cache only answers when they
//  fail for connectivity reasons.
//
//  The protocol keeps `ProductLookupService` testable with an in-memory fake; the
//  SwiftData implementation is the production backing. Cache methods are
//  MainActor-isolated because `ModelContext` is not Sendable.
//

import Foundation
import SwiftData

/// Abstracts the persistent product cache so the lookup service can be tested
/// without SwiftData.
protocol ProductCaching {
    @MainActor func cached(barcode: String) -> Product?
    @MainActor func store(_ product: Product)
}

/// One cached product row. `barcode` is unique so a re-scan upserts.
@Model
final class CachedProduct {
    @Attribute(.unique) var barcode: String
    var name: String
    var brand: String?
    var rawIngredientsText: String?
    var additivesENumbers: [String]
    var labels: [String]
    var cachedAt: Date

    init(barcode: String, name: String, brand: String?, rawIngredientsText: String?,
         additivesENumbers: [String], labels: [String], cachedAt: Date = .now) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.rawIngredientsText = rawIngredientsText
        self.additivesENumbers = additivesENumbers
        self.labels = labels
        self.cachedAt = cachedAt
    }

    convenience init(_ p: Product) {
        self.init(barcode: p.id, name: p.name, brand: p.brand,
                  rawIngredientsText: p.rawIngredientsText,
                  additivesENumbers: p.additivesENumbers, labels: p.labels)
    }

    func update(from p: Product) {
        name = p.name
        brand = p.brand
        rawIngredientsText = p.rawIngredientsText
        additivesENumbers = p.additivesENumbers
        labels = p.labels
        cachedAt = .now
    }

    func asProduct() -> Product {
        Product(id: barcode, name: name, brand: brand,
                rawIngredientsText: rawIngredientsText,
                additivesENumbers: additivesENumbers, labels: labels)
    }
}

/// Production cache backed by SwiftData.
@MainActor
final class SwiftDataProductCache: ProductCaching {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func cached(barcode: String) -> Product? {
        let descriptor = FetchDescriptor<CachedProduct>(
            predicate: #Predicate { $0.barcode == barcode })
        return (try? context.fetch(descriptor))?.first?.asProduct()
    }

    func store(_ product: Product) {
        let bc = product.id
        let descriptor = FetchDescriptor<CachedProduct>(
            predicate: #Predicate { $0.barcode == bc })
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.update(from: product)
        } else {
            context.insert(CachedProduct(product))
        }
        try? context.save()
    }
}

//
//  Product.swift
//  Haliable
//
//  Created by Omar O on 5/25/26.
//

import Foundation

// Our app's clean model of a scanned product.
// Filled in later by the Open Food Facts service.
struct Product: Identifiable, Hashable {
    let id: String                  // the barcode
    let name: String
    let brand: String?              // optional — might not be listed
    let rawIngredientsText: String? // optional — might not be listed
    let additivesENumbers: [String] // e.g. ["E120", "E441"]; empty if none

    /// Open Food Facts `labels_tags` (e.g. ["en:halal", "en:jakim"]). Used to
    /// detect a halal certifier and compare it to the user's standard. Defaults
    /// to empty so existing callers/tests/previews keep compiling.
    var labels: [String] = []

    /// Open Food Facts `ingredients_tags` — its taxonomy reading of the label in
    /// English ("en:pork-gelatin") whatever language the label is in. The engine
    /// uses the "en:" ones only to fill in what the text itself doesn't name.
    var ingredientTags: [String] = []
}

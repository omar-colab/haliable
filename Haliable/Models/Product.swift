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
}

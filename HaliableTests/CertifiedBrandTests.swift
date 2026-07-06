//
//  CertifiedBrandTests.swift
//  HaliableTests
//
//  The bundled certified-brands directory (CertifiedBrandStore) recovers a
//  certifying body from a product's BRAND when Open Food Facts has no certifier
//  label. These tests pin the matching contract: real brands resolve (including
//  OFF's comma-joined brand strings and corporate-suffix noise), short generic
//  tokens never false-positive into a longer brand, and unknowns stay nil.
//

import XCTest
@testable import Haliable

final class CertifiedBrandTests: XCTestCase {

    private let store = CertifiedBrandStore(brands: [
        CertifiedBrand(name: "Saffron Road", aliases: nil, certifier: "ifanca", region: "us", category: nil),
        CertifiedBrand(name: "Pik Nik Foods", aliases: ["Pik-Nik"], certifier: "hfsaa", region: "us", category: nil),
        CertifiedBrand(name: "Greener Pastures Chicken", aliases: nil, certifier: "hfsaa", region: "us", category: nil),
        CertifiedBrand(name: "Crescent Foods", aliases: ["Crescent Halal"], certifier: "ifanca", region: "us", category: nil),
    ])

    func testExactBrandResolvesToBody() {
        XCTAssertEqual(store.certifier(forBrand: "Saffron Road"), .ifanca)
    }

    func testAliasResolves() {
        XCTAssertEqual(store.certifier(forBrand: "Crescent Halal"), .ifanca)
    }

    func testCorporateSuffixAndPunctuationNormalized() {
        // OFF/USDA often append "Foods", "Inc", "USA", or hyphenate.
        XCTAssertEqual(store.certifier(forBrand: "Pik-Nik Foods, USA"), .hfsaa)
    }

    func testCommaJoinedBrandsMatchAnyPiece() {
        // OFF returns brands_tags as a comma-joined string.
        XCTAssertEqual(store.certifier(forBrand: "Generic Store Brand, Saffron Road"), .ifanca)
    }

    func testLeadingTokenMatchAllowsTrailingDescriptor() {
        XCTAssertEqual(store.certifier(forBrand: "Saffron Road Organic Lentils"), .ifanca)
    }

    func testShortGenericTokenDoesNotFalseMatchLongerBrand() {
        // "Green" must NOT resolve to "Greener Pastures Chicken".
        XCTAssertNil(store.certifier(forBrand: "Green"))
    }

    func testUnknownBrandIsNil() {
        XCTAssertNil(store.certifier(forBrand: "Totally Unlisted Brand"))
    }

    func testNilAndEmptyAreNil() {
        XCTAssertNil(store.certifier(forBrand: nil))
        XCTAssertNil(store.certifier(forBrand: ""))
    }

    func testBundledDirectoryLoadsRealBrands() {
        // The shipped JSON should decode and resolve a flagship brand.
        XCTAssertEqual(CertifiedBrandStore.shared.certifier(forBrand: "Saffron Road"), .ifanca)
        XCTAssertGreaterThan(CertifiedBrandStore.shared.brandCount, 20)
    }
}

//
//  DemoBarcodeProbeTests.swift
//  HaliableTests
//
//  A LIVE probe for the interview demo kit, not a unit test.
//
//  It runs each candidate barcode through the app's real lookup chain
//  (USDA → Open Food Facts) and prints, per barcode: the product name, which
//  source answered, the verdict under all four standards, the ingredient driving
//  the worst grade, and whether that grade is still a draft awaiting a citation.
//
//  It hits the network and depends on third-party data, so it is SKIPPED unless
//  explicitly asked for — otherwise it would make the normal suite flaky and
//  offline-hostile. Run it on purpose:
//
//  To run it, set HALIABLE_DEMO_PROBE=1 in the scheme's Test action:
//    Xcode → Product → Scheme → Edit Scheme → Test → Arguments →
//    Environment Variables → add HALIABLE_DEMO_PROBE = 1, then run
//      xcodebuild test -scheme Haliable \
//        -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
//        -only-testing:HaliableTests/DemoBarcodeProbeTests CODE_SIGNING_ALLOWED=NO
//
//  NOTE: passing the variable on the xcodebuild command line does NOT work for a
//  unit-test target, with or without the TEST_RUNNER_ prefix — that prefix only
//  forwards into UI-test runner processes. Verified: the test skips silently.
//  The alternative is a test plan with the variable set.
//
//  A barcode that prints NOT FOUND or "no ingredients" is one to swap before the
//  interview — that is the whole point of running this.
//

import XCTest
@testable import Haliable

@MainActor
final class DemoBarcodeProbeTests: XCTestCase {

    /// Candidate demo products, one per slot in the Phase 6 kit. Swap freely —
    /// the probe tells you whether a barcode actually resolves.
    private static let candidates: [(slot: String, barcode: String, note: String)] = [
        ("1 certified",      "0049000028911", "reviewer barcode from the plan (Coca-Cola)"),
        ("2 gelatin",        "0041420006104", "Haribo Goldbears — gelatin, the standard-switch moment"),
        ("3 mono/digly",     "0072250007214", "bread/pastry with mono- and diglycerides"),
        ("4 natural flavor", "0028400090000", "chips with natural flavors"),
        ("5 carmine",        "0041420104060", "red candy / yogurt with carmine"),
        ("6 clean staple",   "0041331092609", "plain staple — a clean halal result"),
    ]

    func testProbeDemoBarcodes() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["HALIABLE_DEMO_PROBE"] == "1",
            "Live network probe. Set HALIABLE_DEMO_PROBE=1 to run."
        )

        let engine = RulesEngine()
        var report: [String] = []
        report.append("")
        report.append(String(repeating: "=", count: 78))
        report.append("DEMO BARCODE PROBE — \(Self.candidates.count) candidates")
        report.append(String(repeating: "=", count: 78))

        for c in Self.candidates {
            report.append("")
            report.append("[\(c.slot)]  \(c.barcode)   — \(c.note)")

            // Each lookup gets its own service so one failure can't poison the next.
            let product: Product
            do {
                product = try await ProductLookupService().fetchProduct(barcode: c.barcode)
            } catch {
                report.append("   ❌ NOT FOUND — \(error.localizedDescription)")
                report.append("   → SWAP THIS PRODUCT.")
                continue
            }

            report.append("   name    : \(product.name)")
            report.append("   brand   : \(product.brand ?? "—")")

            let ingredientsText = product.rawIngredientsText ?? ""
            if ingredientsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                report.append("   ⚠️  NO INGREDIENTS — resolves, but the verdict screen has nothing to show.")
                report.append("   → SWAP THIS PRODUCT.")
                continue
            }
            report.append("   chars   : \(ingredientsText.count) of ingredient text")

            // The demo's money shot is a product whose verdict CHANGES with the
            // standard, so report all four and say whether they diverge.
            var grades: [String] = []
            var distinct = Set<String>()
            for standard in HalalStandard.allCases {
                let verdict = engine.evaluate(product: product, standard: standard)
                let worst = verdict.flagged.first
                let driver = worst?.originalText ?? "—"
                let draft = (worst?.needsReview ?? false) ? " (draft)" : ""
                grades.append("      \(standard.rawValue.padding(toLength: 14, withPad: " ", startingAt: 0))"
                              + "\(verdict.overallGrade)\(draft)   driver: \(driver.prefix(34))")
                distinct.insert("\(verdict.overallGrade)")
            }
            report.append("   verdicts:")
            report.append(contentsOf: grades)
            report.append(distinct.count > 1
                ? "   ⭐️ DIVERGES across standards — good for the standard-switch moment."
                : "   • same verdict under all four standards.")
        }

        report.append("")
        report.append(String(repeating: "=", count: 78))
        print(report.joined(separator: "\n"))

        // The probe is a report, not a gate: it must not fail the build just
        // because a third-party database changed. Read the output.
        XCTAssertFalse(Self.candidates.isEmpty)
    }
}

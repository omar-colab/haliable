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
//  Run it from the command line (the only path that is actually verified):
//
//    D=$(xcrun simctl list devices | awk '/iPhone 17 Pro \(/{print $NF}' | tr -d '()' | head -1)
//    xcrun simctl bootstatus "$D" -b
//    xcrun simctl spawn "$D" defaults write app.haliable.ios HALIABLE_DEMO_PROBE -int $(date +%s)
//    xcodebuild test -scheme Haliable -derivedDataPath build/dd \
//      -destination "platform=iOS Simulator,id=$D" \
//      -only-testing:HaliableTests/DemoBarcodeProbeTests CODE_SIGNING_ALLOWED=NO
//
//  Or just: ./scripts/run-demo-probe.sh  (does all of the above and prints the report).
//
//  The flag is a timestamp, honoured for ten minutes, so it never leaks into a later
//  run of the normal suite — which is the whole point, that suite must stay
//  offline-safe.
//
//  The defaults flag is read instead of an environment variable because xcodebuild
//  CANNOT set an env var on a unit-test host — verified, twice: plain and
//  TEST_RUNNER_-prefixed both skip silently (TEST_RUNNER_ only forwards into
//  UI-test runners), and `simctl spawn launchctl setenv` does not reach the test
//  host either, with or without -parallel-testing-enabled NO. The test target is
//  hosted by Haliable.app, so UserDefaults.standard here IS the app's domain,
//  which simctl can write from outside. In Xcode, the scheme's Test → Arguments →
//  Environment Variables route still works and is also accepted.
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
    /// The demo kit, chosen from a 14-barcode sweep on Oct 14, 2026 — see
    /// `docs/demo/DEMO_SCRIPT.md` for what each one is for and what it printed.
    /// Re-run the probe the morning of the demo: these are third-party databases
    /// and a product can change or disappear without warning.
    private static let candidates: [(slot: String, barcode: String, note: String)] = [
        ("1 clean",      "044000032029",  "Oreo — halal under all four standards"),
        ("2 cited split","0051500255162", "Jif Creamy Peanut Butter — mono- & diglycerides, diverges, citation is live"),
        ("3 hard split", "070470003016",  "Yoplait red raspberry — haram under Zabiha only. The money shot"),
        ("4 clear haram","0034856008187", "Welch's Fruit Snacks — gelatin/pork, haram under all four"),
        ("5 enzymes",    "028400433303",  "Cheetos XXtra Flamin' Hot — enzymes, diverges"),
        ("6 honest draft","0049000028911", "Diet Coke — E150C has no citation yet, so it shows as a draft"),
    ]

    func testProbeDemoBarcodes() async throws {
        // Two ways in, because xcodebuild cannot set an environment variable on a
        // unit-test host: the defaults flag is the command-line path, the env var
        // is the Xcode-scheme path. See the header.
        //
        // The defaults flag is a DEADLINE, not a boolean — `run-demo-probe.sh`
        // writes the current unix time and this accepts it for ten minutes. That
        // is deliberate: a leftover flag would quietly put a network-dependent test
        // back into the normal suite, and clearing it afterwards is NOT reliable.
        // `simctl spawn defaults write` lands in a store that `removeObject` here
        // cannot clear (verified: the probe re-ran unasked), and the runner leaves
        // the simulator shut down, so a cleanup step in the script cannot always
        // reach it either. A deadline needs no cleanup to be safe.
        let key = "HALIABLE_DEMO_PROBE"
        let requestedAt = UserDefaults.standard.double(forKey: key)
        let withinWindow = requestedAt > 0
            && Date().timeIntervalSince1970 - requestedAt < 600
        let asked = withinWindow || ProcessInfo.processInfo.environment[key] == "1"
        try XCTSkipUnless(asked, "Live network probe. See the header for how to run it.")

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

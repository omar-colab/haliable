//
//  CertifierDetectTests.swift
//  Certifier codes must match whole words in Open Food Facts label tags.
//

import XCTest
@testable import Haliable

final class CertifierDetectTests: XCTestCase {
    func testRealTagsDetect() {
        XCTAssertEqual(CertificationBody.detect(in: ["en:halal", "en:ifanca"]), .ifanca)
        XCTAssertEqual(CertificationBody.detect(in: ["en:halal-food-authority"]), .hfa)
        XCTAssertEqual(CertificationBody.detect(in: ["en:halal-monitoring-committee"]), .hmc)
        XCTAssertEqual(CertificationBody.detect(in: ["id:lppom-mui"]), .mui)
    }

    func testCodesInsideOtherWordsDoNot() {
        XCTAssertNil(CertificationBody.detect(in: ["fr:desmarais", "en:muir-glen", "en:shahfarm"]))
    }

    func testNegativeHalalTagsAreNotAHalalLabel() {
        XCTAssertTrue(CertificationBody.hasGenericHalalLabel(["en:halal"]))
        XCTAssertFalse(CertificationBody.hasGenericHalalLabel(["en:non-halal"]))
        XCTAssertFalse(CertificationBody.hasGenericHalalLabel(["en:not-halal", "en:organic"]))
    }
}

//
//  AccountServiceTests.swift
//  HaliableTests
//
//  Account lifecycle (Guideline 5.1.1(v)) safety: export and deletion must be
//  inert and non-throwing when there's no signed-in user, so they never hit the
//  network or partially act on an unauthenticated session.
//

import XCTest
@testable import Haliable

@MainActor
final class AccountServiceTests: XCTestCase {

    func testExportIsEmptyWhenSignedOut() async throws {
        let service = AccountService()
        let export = try await service.fetchServerExport(auth: AuthManager())
        XCTAssertTrue(export.reviewRequests.isEmpty)
        XCTAssertTrue(export.storeSubmissions.isEmpty)
        XCTAssertTrue(export.storeVotes.isEmpty)
    }

    func testDeleteServerDataNoOpsWhenSignedOut() async throws {
        // Must return without throwing (and without touching the network).
        let service = AccountService()
        try await service.deleteServerData(auth: AuthManager())
    }

    func testServerExportEncodesToJSON() throws {
        let export = ServerExport(
            reviewRequests: [ExportReview(id: "r1", product_name: "Gum", barcode: "123",
                                          status: "pending", verdict: nil, created_at: "2026-06-01")],
            storeSubmissions: [ExportStore(id: "s1", name: "Mart", status: "approved",
                                           created_at: "2026-06-01")],
            storeVotes: [ExportVote(store_id: "s1", vote: "confirm", created_at: "2026-06-01")])
        let data = try JSONEncoder().encode(export)
        let round = try JSONDecoder().decode(ServerExport.self, from: data)
        XCTAssertEqual(round.reviewRequests.first?.product_name, "Gum")
        XCTAssertEqual(round.storeVotes.first?.vote, "confirm")
    }
}

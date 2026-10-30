//
//  StoreServiceTests.swift
//  HaliableTests
//
//  Phase 1 of the Store Atlas read path. Two contracts are pinned here:
//
//  1. Honest fallback — when the live backend is unavailable, the map shows NO
//     stores and a notice. It must never invent halal places. Pinned with
//     StoreService(forceOffline:) so it tests the contract rather than whether
//     the Supabase package happens to be linked in this build.
//
//  2. Decode shape — a row from the `stores_nearby` RPC must decode straight into
//     `Store` with no translation layer. This test encodes the exact column names
//     the SQL function returns and asserts every field round-trips, so a drift
//     between the migration's RETURNS TABLE and the client model fails loudly.
//

import XCTest
import CoreLocation
@testable import Haliable

@MainActor
final class StoreServiceTests: XCTestCase {

    private let center = CLLocationCoordinate2D(latitude: 40.7308, longitude: -73.9975)

    // MARK: - Fallback read path (mock build)

    // Regression: the fallback used to pin five invented stores (fake certifier
    // badges, random confirm counts) around the user's real location. One network
    // blip in a demo would have shown made-up halal places.
    func testFallbackShowsNoInventedStores() async {
        // forceOffline, not "the package isn't linked" — the suite used to rely on
        // the latter, which quietly stopped being true the moment Supabase was
        // linked properly, and would also have made this test hit the real network.
        let service = StoreService(forceOffline: true)
        await service.loadNearby(center: center)
        XCTAssertFalse(service.isLive, "forceOffline must pin the offline path")
        XCTAssertTrue(service.stores.isEmpty, "an unreachable backend must never invent stores")
        XCTAssertNotNil(service.lastError, "an empty map needs a reason on screen")
        XCTAssertFalse(service.isLoading)
    }

    // The category filter is a live-path concern now that there is no bundled seed.
    func testCategoryFilterOnOfflinePathStillReturnsNothing() async {
        let service = StoreService(forceOffline: true)
        await service.loadNearby(center: center, category: .butcher)
        XCTAssertTrue(service.stores.isEmpty)
        XCTAssertNotNil(service.lastError)
    }

    // MARK: - RPC row → Store decode contract

    func testStoreDecodesFromNearbyRPCRow() throws {
        // Mirrors public.stores_nearby's RETURNS TABLE column names exactly.
        let json = """
        {
          "id": "00000000-0000-4000-8000-000000000001",
          "name": "Al-Noor Halal Market",
          "category": "grocery",
          "halal_scope": "fully_halal",
          "address": "123 Sample St",
          "city": "Sampletown",
          "state": "NY",
          "zip": "10001",
          "lat": 40.7348,
          "lng": -73.9945,
          "certifications": ["HMS"],
          "status": "approved",
          "confirm_count": 12,
          "dispute_count": 0,
          "distance_m": 487.5,
          "created_at": "2026-06-01T00:00:00+00:00"
        }
        """.data(using: .utf8)!

        let store = try JSONDecoder().decode(Store.self, from: json)
        XCTAssertEqual(store.name, "Al-Noor Halal Market")
        XCTAssertEqual(store.category, .grocery)
        XCTAssertEqual(store.halalScope, .fullyHalal)
        XCTAssertEqual(store.certifications, ["HMS"])
        XCTAssertEqual(store.status, .approved)
        XCTAssertEqual(store.confirmCount, 12)
        XCTAssertEqual(store.distanceM ?? -1, 487.5, accuracy: 0.001)
        XCTAssertEqual(store.lat, 40.7348, accuracy: 1e-6)
        XCTAssertEqual(store.lng, -73.9945, accuracy: 1e-6)
    }

    // MARK: - Submit validation (client side)

    private func draft(name: String = "Madinah Market",
                       state: String = "NY", zip: String = "10001",
                       lat: Double = 40.7308, lng: Double = -73.9975) -> StoreDraft {
        var d = StoreDraft(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
        d.name = name; d.category = .grocery; d.halalScope = .fullyHalal
        d.address = "1 Test St"; d.city = "Testville"; d.state = state; d.zip = zip
        return d
    }

    func testValidateAcceptsGoodDraft() throws {
        XCTAssertNoThrow(try StoreService.validate(draft()))
    }

    func testValidateRejectsShortName() {
        XCTAssertThrowsError(try StoreService.validate(draft(name: "A"))) {
            XCTAssertEqual($0 as? StoreSubmitError, .invalidName)
        }
    }

    func testValidateRejectsNullIslandLocation() {
        XCTAssertThrowsError(try StoreService.validate(draft(lat: 0, lng: 0))) {
            XCTAssertEqual($0 as? StoreSubmitError, .invalidLocation)
        }
    }

    func testValidateRejectsOutOfRangeLocation() {
        XCTAssertThrowsError(try StoreService.validate(draft(lat: 120, lng: 10))) {
            XCTAssertEqual($0 as? StoreSubmitError, .invalidLocation)
        }
    }

    func testValidateRejectsBadState() {
        XCTAssertThrowsError(try StoreService.validate(draft(state: "New York"))) {
            XCTAssertEqual($0 as? StoreSubmitError, .invalidState)
        }
    }

    func testValidateRejectsBadZip() {
        XCTAssertThrowsError(try StoreService.validate(draft(zip: "ABC"))) {
            XCTAssertEqual($0 as? StoreSubmitError, .invalidZip)
        }
    }

    func testValidateAllowsEmptyOptionalAddressFields() throws {
        // State/ZIP are optional; empty must pass (only malformed non-empty fails).
        XCTAssertNoThrow(try StoreService.validate(draft(state: "", zip: "")))
    }

    func testSubmitThrowsWhenSignedOut() async {
        let service = StoreService(forceOffline: true)
        let auth = AuthManager()   // fresh = signed out
        do {
            try await service.submit(draft(), auth: auth)
            XCTFail("submit should require sign-in")
        } catch {
            XCTAssertEqual(error as? StoreSubmitError, .notSignedIn)
        }
    }

    func testServerErrorMappingForDuplicate() {
        struct Dup: LocalizedError { var errorDescription: String? { "duplicate store nearby: 123" } }
        XCTAssertEqual(StoreSubmitError.from(Dup()), .duplicateNearby)
    }

    // MARK: - Confirm / dispute votes

    private func sampleStore() -> Store {
        Store(id: UUID(), name: "Voteworthy", category: .grocery, halalScope: .fullyHalal,
              address: "1 St", city: "C", state: "NY", zip: "10001",
              lat: 40.73, lng: -73.99, certifications: [], status: .approved,
              confirmCount: 3, disputeCount: 0, distanceM: nil, createdAt: "2026-06-01T00:00:00Z")
    }

    func testConfirmRequiresSignIn() async {
        let service = StoreService(forceOffline: true)
        do { _ = try await service.confirm(sampleStore(), auth: AuthManager()); XCTFail("should require sign-in") }
        catch { XCTAssertEqual(error as? StoreSubmitError, .notSignedIn) }
    }

    func testDisputeRequiresSignIn() async {
        let service = StoreService(forceOffline: true)
        do { _ = try await service.dispute(sampleStore(), auth: AuthManager()); XCTFail("should require sign-in") }
        catch { XCTAssertEqual(error as? StoreSubmitError, .notSignedIn) }
    }

    func testVoteResultDecodesFromRPCRow() throws {
        let json = #"{"confirm_count": 13, "dispute_count": 2}"#.data(using: .utf8)!
        let result = try JSONDecoder().decode(StoreVoteResult.self, from: json)
        XCTAssertEqual(result.confirmCount, 13)
        XCTAssertEqual(result.disputeCount, 2)
    }

    // MARK: - Decode edge

    func testStoreDecodesWithNullDistance() throws {
        // distance_m may be absent when a row isn't returned from the spatial RPC.
        let json = """
        { "id": "00000000-0000-4000-8000-000000000009", "name": "X", "category": "cafe",
          "halal_scope": "unverified", "address": "", "city": "", "state": "", "zip": "",
          "lat": 1.0, "lng": 2.0, "certifications": [], "status": "approved",
          "confirm_count": 0, "dispute_count": 0, "created_at": "2026-06-01T00:00:00Z" }
        """.data(using: .utf8)!
        let store = try JSONDecoder().decode(Store.self, from: json)
        XCTAssertNil(store.distanceM)
        XCTAssertEqual(store.halalScope, .unverified)
    }

    /// The bundled Connecticut list loads, stays inside Connecticut, never claims a
    /// verified scope (report, don't rule), and keeps the same ids across launches.
    func testConnecticutListLoads() throws {
        let list = StoreService.loadConnecticut()
        XCTAssertGreaterThan(list.places.count, 40)
        XCTAssertEqual(Set(list.places.map(\.id)).count, list.places.count)
        for p in list.places {
            XCTAssertTrue((40.95...42.06).contains(p.lat) && (-73.75 ... -71.78).contains(p.lng), p.name)
            XCTAssertEqual(p.state, "CT", p.name)
            XCTAssertEqual(p.halalScope, .unverified, p.name)
            XCTAssertTrue(p.isExternal, p.name)
            if let menu = p.menuURL { XCTAssertEqual(menu.scheme, "https", p.name) }
        }
        XCTAssertGreaterThan(list.places.filter { $0.menuURL != nil }.count, 25)
        XCTAssertFalse(list.verifiedMenus.isEmpty)
        XCTAssertEqual(StoreService.loadConnecticut().places.first?.id, list.places.first?.id)
    }

    /// Distances come from the person's location; without one there are none.
    func testPlacesNearUserGetDistances() throws {
        let service = StoreService(forceOffline: true)
        XCTAssertTrue(service.places(near: nil).allSatisfy { $0.distanceM == nil })
        let near = service.places(near: CLLocationCoordinate2D(latitude: 41.8077, longitude: -72.2540))
        XCTAssertTrue(near.allSatisfy { $0.distanceM != nil })
    }
}

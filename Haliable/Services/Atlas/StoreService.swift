//
//  StoreService.swift
//  Haliable
//
//  The Store Atlas data source. The READ path is now live: `loadNearby` calls the
//  Supabase `stores_nearby` spatial RPC (PostGIS radius query, approved-only) when
//  Supabase is configured, and decodes rows straight into `Store`. If Supabase is
//  unconfigured or the call fails, the map is EMPTY with a notice (`lastError`) —
//  never invented stores. A halal app must not pin fake halal places near a user.
//
//  The whole live path is gated behind `canImport(Supabase)` so the project builds
//  before the supabase-swift package is added. The WRITE path (`submit`, confirm,
//  dispute) is wired in Phase 2.
//

import Foundation
import CoreLocation
import Observation
#if canImport(Supabase)
import Supabase
#endif

@Observable
final class StoreService {
    private(set) var stores: [Store] = []
    private(set) var isLoading = false
    var lastError: String?

    /// True when the live Supabase backend is available (package + secrets present).
    var isLive: Bool {
        #if canImport(Supabase)
        return SupabaseManager.shared != nil
        #else
        return false
        #endif
    }

    func loadNearby(center: CLLocationCoordinate2D, radiusKm: Double = 5,
                    category: StoreCategory? = nil) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        #if canImport(Supabase)
        if let client = SupabaseManager.shared {
            do {
                let params = NearbyParams(in_lat: center.latitude, in_lng: center.longitude,
                                          in_radius_km: radiusKm, in_category: category?.rawValue)
                let rows: [Store] = try await client
                    .rpc(SupabaseConfig.nearbyStoresRPC, params: params)
                    .execute()
                    .value
                stores = rows
                return
            } catch {
                lastError = "Couldn't reach the store map. Check your connection and try again."
                stores = []
                return
            }
        }
        #endif

        // Not live (no package / no secrets): nothing real to show.
        lastError = "The store map isn't connected yet."
        stores = []
    }

    /// Submit a community store. Validates client-side, then (when live) calls the
    /// `submit_store` RPC, which re-validates and dedupes server-side before
    /// inserting a `pending`/`community` row owned by the signed-in user. The new
    /// row is invisible on the public map until an admin approves it, so we do NOT
    /// add it to `stores` in the live path. Offline, we add an optimistic pending
    /// pin so the flow is demoable without a backend.
    func submit(_ draft: StoreDraft, auth: AuthManager) async throws {
        guard auth.isSignedIn else { throw StoreSubmitError.notSignedIn }
        try Self.validate(draft)

        #if canImport(Supabase)
        if let client = SupabaseManager.shared {
            do {
                let _: UUID = try await client
                    .rpc(SupabaseConfig.submitStoreRPC, params: SubmitParams(draft))
                    .execute()
                    .value
            } catch {
                throw StoreSubmitError.from(error)
            }
            return
        }
        #endif

        // Offline mock: optimistic local pending pin.
        stores.insert(draft.asPendingStore(), at: 0)
    }

    /// One community vote: confirm a place is still halal, or flag an issue. Each
    /// returns the fresh confirm/dispute counts. Backed by the `vote_store` RPC,
    /// which enforces one vote per user (re-voting replaces it) and only allows
    /// votes on approved stores. Offline, it optimistically bumps the local count.
    @discardableResult
    func confirm(_ store: Store, auth: AuthManager) async throws -> StoreVoteResult {
        try await vote(store, "confirm", auth: auth)
    }

    @discardableResult
    func dispute(_ store: Store, auth: AuthManager) async throws -> StoreVoteResult {
        try await vote(store, "dispute", auth: auth)
    }

    private func vote(_ store: Store, _ vote: String, auth: AuthManager) async throws -> StoreVoteResult {
        guard auth.isSignedIn else { throw StoreSubmitError.notSignedIn }

        #if canImport(Supabase)
        if let client = SupabaseManager.shared {
            do {
                let rows: [StoreVoteResult] = try await client
                    .rpc(SupabaseConfig.voteStoreRPC,
                         params: VoteParams(in_store_id: store.id, in_vote: vote))
                    .execute()
                    .value
                guard let result = rows.first else {
                    throw StoreSubmitError.server("No response from the server.")
                }
                applyCounts(result, to: store.id)
                return result
            } catch let e as StoreSubmitError {
                throw e
            } catch {
                throw StoreSubmitError.from(error)
            }
        }
        #endif

        // Offline mock: optimistic local increment.
        let result = StoreVoteResult(
            confirmCount: store.confirmCount + (vote == "confirm" ? 1 : 0),
            disputeCount: store.disputeCount + (vote == "dispute" ? 1 : 0))
        applyCounts(result, to: store.id)
        return result
    }

    /// Reflect updated vote counts in the in-memory list so the map stays fresh.
    private func applyCounts(_ result: StoreVoteResult, to id: UUID) {
        guard let i = stores.firstIndex(where: { $0.id == id }) else { return }
        let s = stores[i]
        stores[i] = Store(id: s.id, name: s.name, category: s.category, halalScope: s.halalScope,
                          address: s.address, city: s.city, state: s.state, zip: s.zip,
                          lat: s.lat, lng: s.lng, certifications: s.certifications, status: s.status,
                          confirmCount: result.confirmCount, disputeCount: result.disputeCount,
                          distanceM: s.distanceM, createdAt: s.createdAt)
    }

    // MARK: Client-side validation

    /// Mirror of the server checks in `submit_store`, run before the network call
    /// for fast feedback. The server re-validates — this never replaces it.
    static func validate(_ draft: StoreDraft) throws {
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            throw StoreSubmitError.invalidName
        }
        let lat = draft.coordinate.latitude, lng = draft.coordinate.longitude
        let inRange = (-90...90).contains(lat) && (-180...180).contains(lng)
        let isNullIsland = abs(lat) < 0.0001 && abs(lng) < 0.0001
        if !inRange || isNullIsland { throw StoreSubmitError.invalidLocation }

        let state = draft.state.trimmingCharacters(in: .whitespaces)
        if !state.isEmpty,
           !(state.count == 2 && state.allSatisfy { $0.isLetter }) {
            throw StoreSubmitError.invalidState
        }
        let zip = draft.zip.trimmingCharacters(in: .whitespaces)
        if !zip.isEmpty, !(zip.count == 5 && zip.allSatisfy { $0.isNumber }) {
            throw StoreSubmitError.invalidZip
        }
    }
}

/// Form payload for submitting a store (scaffold).
struct StoreDraft {
    var name = ""
    var category: StoreCategory = .grocery
    var halalScope: HalalScope = .unverified
    var address = ""
    var city = ""
    var state = ""
    var zip = ""
    var coordinate: CLLocationCoordinate2D

    func asPendingStore() -> Store {
        Store(id: UUID(), name: name, category: category, halalScope: halalScope,
              address: address, city: city, state: state, zip: zip,
              lat: coordinate.latitude, lng: coordinate.longitude,
              certifications: [], status: .pending, confirmCount: 0, disputeCount: 0,
              distanceM: nil, createdAt: "2026-06-06T00:00:00Z")
    }
}

/// Errors surfaced by `StoreService.submit`. Equatable so tests can assert the
/// exact failure without string-matching.
enum StoreSubmitError: LocalizedError, Equatable {
    case notSignedIn
    case invalidName
    case invalidLocation
    case invalidState
    case invalidZip
    case duplicateNearby
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:     return "Sign in with Apple to add a place."
        case .invalidName:     return "Enter a place name (at least 2 characters)."
        case .invalidLocation: return "That location looks off — drop the pin on the place."
        case .invalidState:    return "State should be a 2-letter code (e.g. NY)."
        case .invalidZip:      return "ZIP should be 5 digits."
        case .duplicateNearby: return "A place with that name is already listed here."
        case .server(let m):   return m
        }
    }

    /// Map a backend error into a friendly case by inspecting the RPC's raised
    /// message, without depending on the Supabase SDK's concrete error type.
    static func from(_ error: Error) -> StoreSubmitError {
        let text = error.localizedDescription.lowercased()
        if text.contains("duplicate")            { return .duplicateNearby }
        if text.contains("auth required")        { return .notSignedIn }
        if text.contains("invalid name")         { return .invalidName }
        if text.contains("invalid coordinates")  { return .invalidLocation }
        return .server("Couldn't submit this place. Please try again.")
    }
}

/// Fresh confirm/dispute counts returned by the `vote_store` RPC.
struct StoreVoteResult: Decodable, Equatable {
    let confirmCount: Int
    let disputeCount: Int
    enum CodingKeys: String, CodingKey {
        case confirmCount = "confirm_count"
        case disputeCount = "dispute_count"
    }
}

#if canImport(Supabase)
/// Encodable parameters for the `stores_nearby` RPC. Field names match the SQL
/// function's argument names exactly (snake_case).
private struct NearbyParams: Encodable {
    let in_lat: Double
    let in_lng: Double
    let in_radius_km: Double
    let in_category: String?
}

/// Encodable parameters for the `submit_store` RPC.
private struct SubmitParams: Encodable {
    let in_name: String
    let in_category: String
    let in_halal_scope: String
    let in_address: String
    let in_city: String
    let in_state: String
    let in_zip: String
    let in_lat: Double
    let in_lng: Double

    init(_ d: StoreDraft) {
        in_name = d.name
        in_category = d.category.rawValue
        in_halal_scope = d.halalScope.rawValue
        in_address = d.address
        in_city = d.city
        in_state = d.state
        in_zip = d.zip
        in_lat = d.coordinate.latitude
        in_lng = d.coordinate.longitude
    }
}

/// Encodable parameters for the `vote_store` RPC.
private struct VoteParams: Encodable {
    let in_store_id: UUID
    let in_vote: String
}
#endif

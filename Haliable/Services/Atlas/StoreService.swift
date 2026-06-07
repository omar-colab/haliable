//
//  StoreService.swift
//  Haliable
//
//  SCAFFOLD. The real Store Atlas talks to the Node/Supabase API described in
//  the dossier (GET /api/v1/stores/nearby, POST /api/v1/stores, confirm/dispute).
//  That backend is deferred to a follow-up milestone. Until then this serves a
//  handful of seeded, clearly-fictional sample stores so the map, detail, and
//  submit screens are fully navigable and testable.
//
//  When the backend is ready: replace the bodies of `nearby`, `submit`,
//  `confirm`, and `dispute` with URLSession calls to HALIABLE_API_BASE, passing
//  the bearer token from AuthManager.accessToken(). The method signatures and
//  the Store model already match the API contract.
//

import Foundation
import CoreLocation
import Observation

@Observable
final class StoreService {
    private(set) var stores: [Store] = []
    private(set) var isLoading = false
    var lastError: String?

    /// The base URL of the (future) Haliable API, read from Info.plist.
    private var apiBase: URL? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "HALIABLE_API_BASE") as? String,
              !s.isEmpty else { return nil }
        return URL(string: s)
    }

    /// True once a real backend URL is configured.
    var isLive: Bool { apiBase != nil }

    func loadNearby(center: CLLocationCoordinate2D, radiusKm: Double = 5,
                    category: StoreCategory? = nil) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        // TODO(Atlas backend): when `isLive`, GET \(apiBase)/api/v1/stores/nearby
        //   ?lat=&lng=&radius_km=&category= and decode [Store] from { stores: [...] }.
        // For now, seed around the requested center so pins always appear.
        stores = Self.seed(around: center)
            .filter { category == nil || $0.category == category }
    }

    func submit(_ draft: StoreDraft, auth: AuthManager) async throws {
        // TODO(Atlas backend): POST /api/v1/stores with Bearer token; status='pending'.
        guard auth.isSignedIn else { throw NSError(domain: "Atlas", code: 401,
            userInfo: [NSLocalizedDescriptionKey: "Sign in with Apple to submit a store."]) }
        // Scaffold: optimistically add as a pending pin locally.
        let store = draft.asPendingStore()
        stores.insert(store, at: 0)
    }

    func confirm(_ store: Store, auth: AuthManager) async throws { /* TODO backend */ }
    func dispute(_ store: Store, auth: AuthManager) async throws { /* TODO backend */ }

    // MARK: Seed data (clearly fictional placeholders)

    private static func seed(around c: CLLocationCoordinate2D) -> [Store] {
        let samples: [(String, StoreCategory, HalalScope, Double, Double, [String])] = [
            ("Al-Noor Halal Market", .grocery, .fullyHalal, 0.004, 0.003, ["HMS"]),
            ("Zabiha Meats & Deli", .butcher, .halalMeatOnly, -0.005, 0.002, ["HFSAA"]),
            ("Crescent Kitchen", .restaurant, .halalOptions, 0.002, -0.004, []),
            ("Barakah Bakery", .bakery, .fullyHalal, -0.003, -0.003, []),
            ("Salam Cafe", .cafe, .halalOptions, 0.006, 0.001, [])
        ]
        return samples.map { name, cat, scope, dLat, dLng, certs in
            Store(id: UUID(), name: name, category: cat, halalScope: scope,
                  address: "123 Sample St", city: "Sampletown", state: "NY", zip: "10001",
                  lat: c.latitude + dLat, lng: c.longitude + dLng,
                  certifications: certs, status: .approved, confirmCount: Int.random(in: 2...20),
                  disputeCount: 0, distanceM: nil, createdAt: "2026-06-01T00:00:00Z")
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

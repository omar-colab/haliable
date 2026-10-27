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
import MapKit
import Observation
#if canImport(Supabase)
import Supabase
import Auth   // Swift 6 MemberImportVisibility: Auth types are no longer re-exported by Supabase
#endif

@Observable
final class StoreService {
    private(set) var stores: [Store] = []
    /// Apple Maps "halal" results for wherever the map is pointed (see searchAppleMaps).
    private(set) var appleStores: [Store] = []
    /// Places OpenStreetMap mappers tagged `diet:halal` in the area on screen.
    private(set) var osmStores: [Store] = []
    private(set) var isLoading = false
    var lastError: String?

    /// Forces the offline path even when the live backend is available. Tests use
    /// it to pin the offline contract deterministically instead of relying on whether
    /// the Supabase package happens to be linked — an assumption that silently held for
    /// months while the package was declared but never actually linked to the app target.
    private let forceOffline: Bool

    init(forceOffline: Bool = false) {
        self.forceOffline = forceOffline
    }

    /// True when the live Supabase backend is available (package + secrets present).
    var isLive: Bool {
        if forceOffline { return false }
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
        if isLive, let client = SupabaseManager.shared {
            do {
                let params = NearbyParams(in_lat: center.latitude, in_lng: center.longitude,
                                          in_radius_km: radiusKm, in_category: category?.rawValue)
                let rows: [Store] = try await client
                    .rpc(SupabaseConfig.nearbyStoresRPC, params: params)
                    .execute()
                    .value
                guard !Task.isCancelled else { return }   // a newer pan owns the map now
                stores = rows
                return
            } catch {
                // keep the last good pins on screen; an outage shouldn't empty the map
                guard !Task.isCancelled else { return }
                lastError = "Couldn't load places. Check your connection."
                return
            }
        }
        #endif

        // Not live (no package / no secrets): nothing real to show.
        lastError = "The store map isn't connected yet."
        stores = []
    }

    /// Reload everything for the area on screen: verified Atlas places first (so the
    /// Apple Maps dedupe sees them), then Apple Maps. Distances stay measured from
    /// the user, not from wherever the map was panned to.
    func loadVisible(_ region: MKCoordinateRegion, user: CLLocationCoordinate2D?) async {
        let halfSpanKm = max(region.span.latitudeDelta, region.span.longitudeDelta) * 111 / 2
        await loadNearby(center: region.center, radiusKm: min(max(halfSpanKm, 1), 50))
        guard !Task.isCancelled else { return }
        if let user {
            let here = CLLocation(latitude: user.latitude, longitude: user.longitude)
            for i in stores.indices {
                stores[i].distanceM = CLLocation(latitude: stores[i].lat, longitude: stores[i].lng).distance(from: here)
            }
        }
        await searchOSM(in: region, from: user)
        guard !Task.isCancelled else { return }
        await searchAppleMaps(in: region, from: user)
    }

    /// The area last asked of OpenStreetMap, so panning inside it doesn't re-ask.
    private var osmFetched: (box: MKCoordinateRegion, at: Date)?

    /// Free, no key: the public Overpass API, for places mappers tagged
    /// `diet:halal=yes|only`. Sends only the map's bounding box. Any within 80 m
    /// of an Atlas place is dropped so the verified entry wins.
    func searchOSM(in region: MKCoordinateRegion, from user: CLLocationCoordinate2D?) async {
        if let last = osmFetched, Date().timeIntervalSince(last.at) < 600, Self.contains(last.box, region) { return }
        // ponytail: ask for a box 1.5x the view so small pans stay cached; one
        // public server, fair-use limits — move to a mirror if it ever throttles.
        let box = MKCoordinateRegion(center: region.center,
                                     span: MKCoordinateSpan(latitudeDelta: region.span.latitudeDelta * 1.5,
                                                            longitudeDelta: region.span.longitudeDelta * 1.5))
        let s = box.center.latitude - box.span.latitudeDelta / 2, n = box.center.latitude + box.span.latitudeDelta / 2
        let w = box.center.longitude - box.span.longitudeDelta / 2, e = box.center.longitude + box.span.longitudeDelta / 2
        let query = "[out:json][timeout:15];nwr[\"diet:halal\"~\"^(yes|only)$\"][name](\(s),\(w),\(n),\(e));out center 300;"
        var request = URLRequest(url: URL(string: "https://overpass-api.de/api/interpreter")!)
        request.httpMethod = "POST"
        request.setValue("Haliable iOS (halal map; contact via haliable.netlify.app)", forHTTPHeaderField: "User-Agent")
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")".data(using: .utf8)
        request.timeoutInterval = 20
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200, !Task.isCancelled else { return }
        let origin = user ?? region.center
        let here = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        osmFetched = (box, Date())
        osmStores = Self.osmStores(from: data, here: here).filter { o in
            let po = CLLocation(latitude: o.lat, longitude: o.lng)
            return !stores.contains { CLLocation(latitude: $0.lat, longitude: $0.lng).distance(from: po) < 80 }
        }
    }

    private static func contains(_ outer: MKCoordinateRegion, _ inner: MKCoordinateRegion) -> Bool {
        abs(inner.center.latitude - outer.center.latitude) + inner.span.latitudeDelta / 2 <= outer.span.latitudeDelta / 2
            && abs(inner.center.longitude - outer.center.longitude) + inner.span.longitudeDelta / 2 <= outer.span.longitudeDelta / 2
    }

    /// Overpass JSON → unverified pins. Nodes carry lat/lon, ways/relations a `center`.
    static func osmStores(from data: Data, here: CLLocation) -> [Store] {
        struct Response: Decodable { let elements: [Element] }
        struct Element: Decodable {
            struct Center: Decodable { let lat: Double; let lon: Double }
            let type: String; let id: Int64
            let lat: Double?; let lon: Double?; let center: Center?
            let tags: [String: String]?
        }
        guard let elements = try? JSONDecoder().decode(Response.self, from: data).elements else { return [] }
        let categories: [String: StoreCategory] = [
            "restaurant": .restaurant, "fast_food": .restaurant, "food_court": .restaurant,
            "cafe": .cafe, "bakery": .bakery, "butcher": .butcher, "supermarket": .supermarket,
            "convenience": .grocery, "greengrocer": .grocery, "deli": .grocery,
        ]
        return elements.compactMap { el in
            guard let tags = el.tags, let name = tags["name"], let halal = tags["diet:halal"],
                  let lat = el.lat ?? el.center?.lat, let lng = el.lon ?? el.center?.lon else { return nil }
            let loc = CLLocation(latitude: lat, longitude: lng)
            return Store(id: UUID(uuidString: String(format: "00000000-0000-4000-8%03d-%012llx",
                                                     ["node", "way", "relation"].firstIndex(of: el.type) ?? 9,
                                                     UInt64(el.id) & 0xFFFF_FFFF_FFFF)) ?? UUID(),
                         name: name,
                         category: (tags["amenity"] ?? tags["shop"]).flatMap { categories[$0] } ?? .other,
                         halalScope: .unverified,
                         address: [tags["addr:housenumber"], tags["addr:street"]].compactMap { $0 }.joined(separator: " "),
                         city: tags["addr:city"] ?? "", state: tags["addr:state"] ?? "", zip: tags["addr:postcode"] ?? "",
                         lat: lat, lng: lng, certifications: [], status: .pending,
                         confirmCount: 0, disputeCount: 0, distanceM: loc.distance(from: here), createdAt: "",
                         external: .openStreetMap(onlyHalal: halal == "only"))
        }
    }

    /// Fill the map beyond the Atlas: ask Apple Maps for "halal" around `region`.
    /// Results come back `.unverified` with `external = .appleMaps`; any within 80 m of
    /// an Atlas place is dropped so the verified entry wins.
    func searchAppleMaps(in region: MKCoordinateRegion, from user: CLLocationCoordinate2D?) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "halal"
        request.region = region
        request.resultTypes = .pointOfInterest
        guard let items = try? await MKLocalSearch(request: request).start().mapItems,
              !Task.isCancelled else { return }
        let origin = user ?? region.center
        let here = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        appleStores = items.compactMap { Store(appleMapItem: $0, from: here) }
            .filter { a in
                let pa = CLLocation(latitude: a.lat, longitude: a.lng)
                return !(stores + osmStores).contains { CLLocation(latitude: $0.lat, longitude: $0.lng).distance(from: pa) < 80 }
            }
    }

    /// Apple's own entry for a place, for its place card (menu link, hours,
    /// photos, phone). Free and on Apple's side; nil when Apple doesn't know it.
    func appleMapItem(for store: Store) async -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = store.name
        request.region = MKCoordinateRegion(center: store.coordinate, latitudinalMeters: 600, longitudinalMeters: 600)
        request.resultTypes = .pointOfInterest
        guard let items = try? await MKLocalSearch(request: request).start().mapItems else { return nil }
        let here = CLLocation(latitude: store.lat, longitude: store.lng)
        return items
            .map { ($0, CLLocation(latitude: $0.placemark.coordinate.latitude,
                                   longitude: $0.placemark.coordinate.longitude).distance(from: here)) }
            .filter { $0.1 < 150 }
            .min { $0.1 < $1.1 }?.0
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
        if isLive, let client = SupabaseManager.shared {
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
        if isLive, let client = SupabaseManager.shared {
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

extension Store {
    /// An Apple Maps result. Kept only when the place's own name says "halal" or
    /// "zabiha": Apple's search matches reviews and menus too, so a category alone
    /// would pin any restaurant that once mentioned the word.
    static let appleFoodCategories: [MKPointOfInterestCategory: StoreCategory] = [
        .restaurant: .restaurant, .cafe: .cafe, .bakery: .bakery,
        .foodMarket: .grocery, .store: .grocery,
    ]

    init?(appleMapItem item: MKMapItem, from here: CLLocation) {
        let name = item.name ?? ""
        let category = item.pointOfInterestCategory.flatMap { Self.appleFoodCategories[$0] }
        let lower = name.lowercased()
        guard lower.contains("halal") || lower.contains("zabiha") else { return nil }
        let p = item.placemark
        let loc = CLLocation(latitude: p.coordinate.latitude, longitude: p.coordinate.longitude)
        self.init(id: UUID(), name: name, category: category ?? .other, halalScope: .unverified,
                  address: [p.subThoroughfare, p.thoroughfare].compactMap { $0 }.joined(separator: " "),
                  city: p.locality ?? "", state: p.administrativeArea ?? "", zip: p.postalCode ?? "",
                  lat: loc.coordinate.latitude, lng: loc.coordinate.longitude,
                  certifications: [], status: .pending, confirmCount: 0, disputeCount: 0,
                  distanceM: loc.distance(from: here), createdAt: "", external: .appleMaps)
    }
}

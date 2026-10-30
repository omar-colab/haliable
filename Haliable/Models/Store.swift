//
//  Store.swift
//  Haliable
//
//  Client model for a halal place on the Store Atlas. Matches the dossier's
//  StoreRow contract so it decodes directly from the (future) Node/Supabase API:
//  GET /api/v1/stores/nearby. The Atlas backend is deferred — for now StoreService
//  serves seeded sample data so the map and detail screens are fully testable.
//

import Foundation
import CoreLocation

enum StoreCategory: String, Codable, CaseIterable, Hashable {
    case grocery, butcher, restaurant, bakery, cafe, supermarket, other

    var displayName: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .grocery, .supermarket: return "cart.fill"
        case .butcher:    return "fork.knife"
        case .restaurant: return "takeoutbag.and.cup.and.straw.fill"
        case .bakery:     return "birthday.cake.fill"
        case .cafe:       return "cup.and.saucer.fill"
        case .other:      return "mappin.circle.fill"
        }
    }
}

enum HalalScope: String, Codable, Hashable {
    case fullyHalal = "fully_halal"
    case halalMeatOnly = "halal_meat_only"
    case halalOptions = "halal_options"
    case unverified

    var displayName: String {
        switch self {
        case .fullyHalal:    return "Fully halal"
        case .halalMeatOnly: return "Halal meat only"
        case .halalOptions:  return "Halal options"
        case .unverified:    return "Unverified"
        }
    }
}

enum StoreStatus: String, Codable, Hashable {
    case pending, approved, rejected, flagged
}

enum ExternalSource: Hashable {
    case appleMaps
    /// `diet:halal=only` (everything halal, per the mapper) vs `yes` (has halal options).
    case openStreetMap(onlyHalal: Bool)

    var name: String {
        switch self {
        case .appleMaps: return "Apple Maps"
        case .openStreetMap: return "OpenStreetMap"
        }
    }

    /// What the source claims, in its own words — reported, not ruled on.
    var claim: String {
        switch self {
        case .appleMaps: return "Listed under halal on Apple Maps"
        case .openStreetMap(let only): return only ? "Tagged \"only halal\" by OpenStreetMap mappers"
                                                   : "Tagged \"halal options\" by OpenStreetMap mappers"
        }
    }
}

struct Store: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let category: StoreCategory
    let halalScope: HalalScope
    let address: String
    let city: String
    let state: String
    let zip: String
    let lat: Double
    let lng: Double
    let certifications: [String]
    let status: StoreStatus
    let confirmCount: Int
    let disputeCount: Int
    var distanceM: Double?
    let createdAt: String
    /// Where an unverified place came from: Apple Maps search, or a halal tag an
    /// OpenStreetMap mapper added. nil = the Haliable Atlas. Nobody here has
    /// verified these, so they can't be voted on. Not in CodingKeys: never sent
    /// to or read from the DB.
    var external: ExternalSource? = nil
    var isExternal: Bool { external != nil }
    /// The place's own menu or ordering page, and its website / phone, from the
    /// bundled Connecticut list. Not in CodingKeys: the DB doesn't carry them.
    var menuURL: URL? = nil
    var website: URL? = nil
    var phone: String? = nil

    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }

    enum CodingKeys: String, CodingKey {
        case id, name, category
        case halalScope = "halal_scope"
        case address, city, state, zip, lat, lng, certifications, status
        case confirmCount = "confirm_count"
        case disputeCount = "dispute_count"
        case distanceM = "distance_m"
        case createdAt = "created_at"
    }
}

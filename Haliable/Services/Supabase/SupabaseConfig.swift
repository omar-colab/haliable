//
//  SupabaseConfig.swift
//  Haliable
//
//  Reads Supabase settings from Info.plist (which in turn pulls them from the
//  git-ignored Secrets.xcconfig). No secret is hard-coded in source. The ANON
//  key is safe to ship — Row-Level Security protects the data. The service-role
//  key must NEVER be in the app.
//

import Foundation

enum SupabaseConfig {
    static var url: URL? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !s.isEmpty, let u = URL(string: s.hasPrefix("http") ? s : "https://\(s)")
        else { return nil }
        return u
    }

    /// The client key. Prefers the new `sb_publishable_…` key and falls back to the
    /// legacy `anon` JWT, so a half-migrated Secrets.xcconfig still builds and runs.
    ///
    /// Either is safe to ship — Row-Level Security, not the key, is what protects the
    /// data. The `sb_secret_…` key must NEVER appear here.
    ///
    /// Supabase retires the legacy anon/service_role keys at the end of 2026, and a
    /// TestFlight build can stay installed for 90 days, so the fallback is a migration
    /// aid rather than a long-term option.
    static var anonKey: String? {
        for key in ["SUPABASE_PUBLISHABLE_KEY", "SUPABASE_ANON_KEY"] {
            if let k = Bundle.main.object(forInfoDictionaryKey: key) as? String,
               !k.isEmpty, !k.hasPrefix("$(") {
                return k
            }
        }
        return nil
    }

    /// True only when both values are present — used to decide whether to use
    /// the live backend or the in-memory mock.
    static var isConfigured: Bool { url != nil && anonKey != nil }

    /// Storage bucket that holds review photos.
    static let reviewPhotoBucket = "review-photos"
    /// Table holding manual-review requests.
    static let reviewTable = "review_requests"

    /// Table holding Store Atlas places.
    static let storesTable = "stores"
    /// Spatial read RPC: approved stores within a radius, nearest first.
    static let nearbyStoresRPC = "stores_nearby"
    /// Validated write RPC: insert a pending community store (server-side dedupe).
    static let submitStoreRPC = "submit_store"
    /// Vote RPC: confirm/dispute a store, returns fresh counts.
    static let voteStoreRPC = "vote_store"
    /// Account deletion RPC (erases the caller's own rows).
    static let deleteAccountRPC = "delete_my_account"

    /// Base URL for the Netlify serverless functions (Sign in with Apple token
    /// store + revoke). Same domain as the privacy policy / landing site.
    static let functionsBase = URL(string: "https://haliable.netlify.app/.netlify/functions")!
}

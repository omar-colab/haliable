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

    static var anonKey: String? {
        let k = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        return (k?.isEmpty == false) ? k : nil
    }

    /// True only when both values are present — used to decide whether to use
    /// the live backend or the in-memory mock.
    static var isConfigured: Bool { url != nil && anonKey != nil }

    /// Storage bucket that holds review photos.
    static let reviewPhotoBucket = "review-photos"
    /// Table holding manual-review requests.
    static let reviewTable = "review_requests"
}

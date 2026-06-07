//
//  SupabaseManager.swift
//  Haliable
//
//  Builds and holds the single SupabaseClient. The whole file is gated behind
//  `canImport(Supabase)` so the project compiles BEFORE you add the
//  supabase-swift Swift Package. Once the package is added and Secrets are set,
//  this becomes the live client used by AuthManager and ReviewStore.
//

#if canImport(Supabase)
import Foundation
import Supabase

enum SupabaseManager {
    /// nil until both the package is present AND Secrets are configured.
    static let shared: SupabaseClient? = {
        guard let url = SupabaseConfig.url, let key = SupabaseConfig.anonKey else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()
}
#endif

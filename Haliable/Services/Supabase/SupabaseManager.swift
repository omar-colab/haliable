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
import Auth   // Swift 6 MemberImportVisibility: Auth types are no longer re-exported by Supabase

enum SupabaseManager {
    /// nil until both the package is present AND Secrets are configured.
    static let shared: SupabaseClient? = {
        guard let url = SupabaseConfig.url, let key = SupabaseConfig.anonKey else { return nil }
        // Opt in to the SDK's next-major behaviour (silences its launch warning). Safe
        // here: AuthManager reads `auth.session`, which refreshes, not the initial event.
        return SupabaseClient(supabaseURL: url, supabaseKey: key,
                              options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true)))
    }()
}
#endif

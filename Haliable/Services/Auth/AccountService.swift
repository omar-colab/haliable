//
//  AccountService.swift
//  Haliable
//
//  Account lifecycle for App Store Guideline 5.1.1(v): assemble the user's data
//  for export, and erase it on deletion. All server work is gated behind
//  `canImport(Supabase)`; the caller (SettingsV2) wipes LOCAL data and signs out
//  after `deleteServerData` returns.
//
//  Deletion order: the DB rows via the security-definer RPC, then the Sign in
//  with Apple revoke (TN3194, Netlify, best-effort, needs the session), then the
//  `delete-account` Edge Function, which deletes the review photos and the auth
//  user. If the revoke function isn't configured, deletion still completes and
//  the user can revoke access in Settings ▸ Apple ID ▸ Sign in with Apple.
//

import Foundation
#if canImport(Supabase)
import Supabase
import Auth   // Swift 6 MemberImportVisibility: Auth types are no longer re-exported by Supabase
#endif

/// The user's server-side records, for the data export.
struct ServerExport: Codable {
    var reviewRequests: [ExportReview] = []
    var storeSubmissions: [ExportStore] = []
    var storeVotes: [ExportVote] = []
}

struct ExportReview: Codable {
    let id: String
    let product_name: String?
    let barcode: String?
    let status: String?
    let verdict: String?
    let created_at: String?
}

struct ExportStore: Codable {
    let id: String
    let name: String?
    let status: String?
    let created_at: String?
}

struct ExportVote: Codable {
    let store_id: String
    let vote: String?
    let created_at: String?
}

@MainActor
final class AccountService {

    /// Pull the user's server-side records for the data export. Returns empty
    /// when not signed in / Supabase unconfigured (the export still includes the
    /// on-device data the caller adds).
    func fetchServerExport(auth: AuthManager) async throws -> ServerExport {
        #if canImport(Supabase)
        if let client = SupabaseManager.shared, let uid = auth.userID {
            let reviews: [ExportReview] = try await client.from("review_requests")
                .select("id,product_name,barcode,status,verdict,created_at")
                .eq("user_id", value: uid).execute().value
            let stores: [ExportStore] = try await client.from("stores")
                .select("id,name,status,created_at")
                .eq("submitted_by", value: uid).execute().value
            let votes: [ExportVote] = try await client.from("store_votes")
                .select("store_id,vote,created_at")
                .eq("user_id", value: uid).execute().value
            return ServerExport(reviewRequests: reviews, storeSubmissions: stores, storeVotes: votes)
        }
        #endif
        return ServerExport()
    }

    /// Erase ALL server-side data for the signed-in user. Caller wipes local data
    /// and signs out afterward.
    func deleteServerData(auth: AuthManager) async throws {
        #if canImport(Supabase)
        guard let client = SupabaseManager.shared, auth.userID != nil else { return }

        // 1. Delete all owned DB rows via the security-definer RPC.
        try await client.rpc(SupabaseConfig.deleteAccountRPC).execute()
        // 2. Revoke the Apple token while the session is still valid (best-effort).
        if let accessToken = await auth.accessToken() {
            await revokeAppleToken(accessToken: accessToken)
        }
        // 3. LAST: the Edge Function removes the review photos and the auth user
        //    itself. It throws on any failure, so the caller can say deletion
        //    didn't finish instead of claiming it did.
        try await client.functions.invoke("delete-account")
        #endif
    }

    // MARK: - Helpers

    #if canImport(Supabase)
    /// POST to the Netlify `apple-revoke` function, authenticated with the user's
    /// Supabase access token. Best-effort: failure must not block data deletion.
    private func revokeAppleToken(accessToken: String) async {
        var request = URLRequest(url: SupabaseConfig.functionsBase.appendingPathComponent("apple-revoke"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 12
        _ = try? await URLSession.shared.data(for: request)
    }
    #endif
}

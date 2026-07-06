//
//  AccountService.swift
//  Haliable
//
//  Account lifecycle for App Store Guideline 5.1.1(v): assemble the user's data
//  for export, and erase it on deletion. All server work is gated behind
//  `canImport(Supabase)`; the caller (SettingsV2) wipes LOCAL data and signs out
//  after `deleteServerData` returns.
//
//  Deletion order (TN3194): revoke the Sign in with Apple token FIRST (while the
//  session is still valid), then delete Storage photos, then the DB rows via the
//  security-definer RPC. Token revocation is best-effort — if the revoke function
//  isn't deployed yet, deletion still completes and the app directs the user to
//  revoke access manually (Settings ▸ Apple ID ▸ Sign in with Apple), which Apple
//  accepts as the fallback.
//

import Foundation
#if canImport(Supabase)
import Supabase
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
        guard let client = SupabaseManager.shared, let uid = auth.userID else { return }

        // 1. Remove the user's review photos (their own Storage folder).
        await deletePhotos(client: client, uid: uid)
        // 2. Delete all owned DB rows via the security-definer RPC.
        try await client.rpc(SupabaseConfig.deleteAccountRPC).execute()
        // 3. LAST: revoke the Apple token + admin-delete the auth user. This runs
        //    last because it removes auth.users, invalidating the session used above.
        if let accessToken = await auth.accessToken() {
            await revokeAppleToken(accessToken: accessToken)
        }
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

    /// Best-effort recursive delete of `review-photos/{uid}/…`.
    private func deletePhotos(client: SupabaseClient, uid: String) async {
        let bucket = client.storage.from(SupabaseConfig.reviewPhotoBucket)
        guard let folders = try? await bucket.list(path: uid) else { return }
        var paths: [String] = []
        for folder in folders {
            let sub = "\(uid)/\(folder.name)"
            if let files = try? await bucket.list(path: sub) {
                paths.append(contentsOf: files.map { "\(sub)/\($0.name)" })
            }
        }
        if !paths.isEmpty { _ = try? await bucket.remove(paths: paths) }
    }
    #endif
}

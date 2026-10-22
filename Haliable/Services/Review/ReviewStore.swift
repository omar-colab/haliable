//
//  ReviewStore.swift
//  Haliable
//
//  Owns the user's manual-review requests: submitting new ones (photos →
//  Supabase Storage, a row → `review_requests`) and refreshing their status.
//
//  Live behaviour is gated behind `canImport(Supabase)` AND SupabaseConfig
//  being configured. Otherwise it runs fully in-memory so the entire UI flow
//  is testable in the Simulator with no backend.
//

import Foundation
import Observation
import UIKit
#if canImport(Supabase)
import Supabase
import Auth   // Swift 6 MemberImportVisibility: Auth types are no longer re-exported by Supabase
#endif

@Observable
final class ReviewStore {
    private(set) var requests: [ReviewRequest] = []
    private(set) var isWorking = false

    #if DEBUG
    /// Set by `previewSeeded`. Makes `refresh` a no-op so a configured Supabase
    /// client can't replace the fixtures with a real (empty) result set the
    /// moment a preview appears.
    fileprivate var isPreviewSeeded = false
    #endif

    var isLive: Bool {
        #if canImport(Supabase)
        return SupabaseConfig.isConfigured
        #else
        return false
        #endif
    }

    // MARK: Submit

    /// Compress + upload photos, then create the review row. Returns the new request.
    @discardableResult
    func submit(images: [UIImage],
                productName: String?,
                barcode: String?,
                notes: String?,
                auth: AuthManager) async throws -> ReviewRequest {
        guard let userID = auth.userID else { throw ReviewError.notSignedIn }
        guard !images.isEmpty else { throw ReviewError.noPhotos }
        isWorking = true
        defer { isWorking = false }

        let requestID = UUID()
        let datas: [Data] = images.compactMap { ImageCompressor.compressedJPEG($0) }
        guard datas.count == images.count else { throw ReviewError.compressionFailed }

        #if canImport(Supabase)
        if let client = SupabaseManager.shared {
            var paths: [String] = []
            for (index, data) in datas.enumerated() {
                let path = "\(userID)/\(requestID.uuidString)/\(index).jpg"
                // supabase-swift 2.x storage upload. Adjust to your installed SDK if needed.
                try await client.storage
                    .from(SupabaseConfig.reviewPhotoBucket)
                    .upload(path, data: data,
                            options: FileOptions(contentType: "image/jpeg"))
                paths.append(path)
            }
            let payload = InsertPayload(
                id: requestID, user_id: userID, product_name: productName,
                barcode: barcode, notes: notes, photo_paths: paths, status: "pending"
            )
            do {
                try await client.from(SupabaseConfig.reviewTable).insert(payload).execute()
            } catch {
                // The server refused the row (daily limit, too-long text): don't
                // leave the photos we just uploaded sitting in storage.
                _ = try? await client.storage.from(SupabaseConfig.reviewPhotoBucket).remove(paths: paths)
                throw error
            }
            try await refresh(auth: auth)
            return requests.first { $0.id == requestID } ?? payload.asRequest()
        }
        #endif

        // Mock path: keep it in memory so the UI works without a backend.
        let request = ReviewRequest(
            id: requestID, userID: userID, productName: productName, barcode: barcode,
            notes: notes, photoPaths: [], status: .pending, verdict: nil,
            verdictReason: nil, createdAt: .now, reviewedAt: nil
        )
        requests.insert(request, at: 0)
        return request
    }

    // MARK: Refresh

    func refresh(auth: AuthManager) async throws {
        #if DEBUG
        if isPreviewSeeded { return }
        #endif
        guard let userID = auth.userID else { requests = []; return }
        #if canImport(Supabase)
        if let client = SupabaseManager.shared {
            let rows: [ReviewRequest] = try await client
                .from(SupabaseConfig.reviewTable)
                .select()
                .eq("user_id", value: userID)
                .order("created_at", ascending: false)
                .execute()
                .value
            requests = rows
            return
        }
        #endif
        // Mock path keeps whatever is already in memory.
    }

    enum ReviewError: LocalizedError {
        case notSignedIn, noPhotos, compressionFailed
        var errorDescription: String? {
            switch self {
            case .notSignedIn:      return "Please sign in with Apple to request a review."
            case .noPhotos:         return "Add at least one photo of the product or its ingredients."
            case .compressionFailed: return "Couldn't process one of the photos. Try again."
            }
        }
    }
}

#if canImport(Supabase)
/// Encodable shape we insert. Snake_case to match the Postgres columns.
private struct InsertPayload: Encodable {
    let id: UUID
    let user_id: String
    let product_name: String?
    let barcode: String?
    let notes: String?
    let photo_paths: [String]
    let status: String

    func asRequest() -> ReviewRequest {
        ReviewRequest(id: id, userID: user_id, productName: product_name, barcode: barcode,
                      notes: notes, photoPaths: photo_paths,
                      status: ReviewStatus(rawValue: status) ?? .pending,
                      verdict: nil, verdictReason: nil, createdAt: .now, reviewedAt: nil)
    }
}
#endif

#if DEBUG
extension ReviewStore {
    /// A store pre-loaded with sample requests, for SwiftUI previews and UI tests.
    ///
    /// Lives in this file because `requests` is `private(set)` — only same-file
    /// extensions may write it. DEBUG-only, so no seeded row can reach a release
    /// build or be mistaken for a real verdict from a reviewer.
    static func previewSeeded(_ requests: [ReviewRequest] = ReviewRequest.samples) -> ReviewStore {
        let store = ReviewStore()
        store.requests = requests
        store.isPreviewSeeded = true
        return store
    }
}
#endif

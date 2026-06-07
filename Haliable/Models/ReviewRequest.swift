//
//  ReviewRequest.swift
//  Haliable
//
//  A user-submitted request for a HUMAN halal verdict on a product the scanner
//  couldn't resolve. Mirrors a row in Supabase's `review_requests` table. Photos
//  live in Supabase Storage; this row references them by path.
//

import Foundation

enum ReviewStatus: String, Codable, Hashable {
    case pending          // submitted, awaiting a reviewer
    case inReview = "in_review"
    case completed        // a verdict is attached

    var displayName: String {
        switch self {
        case .pending:  return "Pending review"
        case .inReview: return "Under review"
        case .completed: return "Reviewed"
        }
    }
}

struct ReviewRequest: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: String
    var productName: String?
    var barcode: String?
    var notes: String?
    var photoPaths: [String]
    var status: ReviewStatus
    var verdict: Verdict?         // set by the reviewer when completed
    var verdictReason: String?    // the written explanation returned to the user
    var createdAt: Date
    var reviewedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case productName = "product_name"
        case barcode
        case notes
        case photoPaths = "photo_paths"
        case status
        case verdict
        case verdictReason = "verdict_reason"
        case createdAt = "created_at"
        case reviewedAt = "reviewed_at"
    }
}

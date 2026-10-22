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
    /// The published sources behind the answer (quotes machine-checked on their pages).
    var sources: [ReviewSource]? = nil

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
        case sources = "evidence"
    }
}

/// One source returned with a review — what it says, and where to read it yourself.
struct ReviewSource: Codable, Hashable {
    let name: String
    let url: String
    let tier: Int
    let quote: String
}

#if DEBUG
extension ReviewRequest {
    /// Preview/test fixtures covering all three `ReviewStatus` cases, so the
    /// Reviews list, status chips and verdict badges can be seen without a
    /// backend or a signed-in account.
    ///
    /// Product names and barcodes here are deliberately INVENTED. A fixture that
    /// attached a halal verdict to a real brand could end up in a screenshot or
    /// a demo and read as an actual ruling on that product — these must never
    /// name a real one.
    static var samples: [ReviewRequest] {
        [
            ReviewRequest(
                id: UUID(uuidString: "A1B2C3D4-0000-4000-8000-000000000001")!,
                userID: "preview-user",
                productName: "Cedar Lane Gummy Bears",
                barcode: "9990000000017",
                notes: "The ingredients just say \"gelatin\" with no source listed.",
                photoPaths: [],
                status: .completed,
                verdict: .doubtful,
                verdictReason: """
                The label lists gelatin without naming its source. We contacted the \
                manufacturer and they would not confirm whether it is bovine or \
                porcine, so we can't clear it. Questionable until the source is \
                stated on the pack.
                """,
                createdAt: Date(timeIntervalSinceNow: -86_400 * 6),
                reviewedAt: Date(timeIntervalSinceNow: -86_400 * 4)
            ),
            ReviewRequest(
                id: UUID(uuidString: "A1B2C3D4-0000-4000-8000-000000000002")!,
                userID: "preview-user",
                productName: "Northwind Chicken Nuggets",
                barcode: "9990000000024",
                notes: "Front of pack says halal but I can't find a certifier mark.",
                photoPaths: [],
                status: .inReview,
                verdict: nil,
                verdictReason: nil,
                createdAt: Date(timeIntervalSinceNow: -86_400 * 2),
                reviewedAt: nil
            ),
            ReviewRequest(
                id: UUID(uuidString: "A1B2C3D4-0000-4000-8000-000000000003")!,
                userID: "preview-user",
                productName: "Amber Valley Marshmallows",
                barcode: nil,
                notes: "Imported, ingredients are not in English.",
                photoPaths: [],
                status: .pending,
                verdict: nil,
                verdictReason: nil,
                createdAt: Date(timeIntervalSinceNow: -60 * 60 * 6),
                reviewedAt: nil
            ),
        ]
    }
}
#endif

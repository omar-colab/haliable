//
//  ReviewDetailView.swift
//  Haliable
//
//  Shows one manual-review request and, once a reviewer has acted, the returned
//  verdict + written explanation — styled like the scanner's verdict so the two
//  paths feel like one product.
//

import SwiftUI

struct ReviewDetailView: View {
    let request: ReviewRequest

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Text(request.productName ?? "Untitled product")
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)
                if let barcode = request.barcode {
                    Text(barcode).font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                }

                if request.status == .completed, let verdict = request.verdict {
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        VerdictBadge(verdict: verdict)
                        Text("Manually reviewed by Haliable")
                            .font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                        if let reason = request.verdictReason {
                            Text(reason).font(DSFont.body).foregroundStyle(DSColor.textPrimary)
                        }
                    }
                    .cardStyle()
                } else {
                    pendingCard
                }

                if let notes = request.notes, !notes.isEmpty {
                    Divider()
                    Text("Your note").font(DSFont.headline).foregroundStyle(DSColor.textPrimary)
                    Text(notes).font(DSFont.body).foregroundStyle(DSColor.textSecondary)
                }

                Divider()
                Text("Submitted \(request.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
            }
            .padding(DSSpacing.md)
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var pendingCard: some View {
        HStack(spacing: DSSpacing.sm) {
            ThinkingOrb(diameter: 40)
            VStack(alignment: .leading, spacing: DSSpacing.xxs / 2) {
                Text(request.status.displayName)
                    .font(DSFont.headline).foregroundStyle(DSColor.textPrimary)
                Text("We'll notify you here once a reviewer has looked at your photos.")
                    .font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
            }
        }
        .surfaceStyle(fill: DSColor.warning.opacity(0.12))
    }
}

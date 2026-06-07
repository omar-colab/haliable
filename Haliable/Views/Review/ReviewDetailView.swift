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
            VStack(alignment: .leading, spacing: 16) {
                Text(request.productName ?? "Untitled product").font(.title2.bold())
                if let barcode = request.barcode {
                    Text(barcode).font(.caption).foregroundStyle(.secondary)
                }

                if request.status == .completed, let verdict = request.verdict {
                    VStack(alignment: .leading, spacing: 10) {
                        VerdictBadge(verdict: verdict)
                        Text("Manually reviewed by Haliable")
                            .font(.caption).foregroundStyle(.secondary)
                        if let reason = request.verdictReason {
                            Text(reason).font(.body)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    pendingCard
                }

                if let notes = request.notes, !notes.isEmpty {
                    Divider()
                    Text("Your note").font(.headline)
                    Text(notes).foregroundStyle(.secondary)
                }

                Divider()
                Text("Submitted \(request.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var pendingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            VStack(alignment: .leading, spacing: 2) {
                Text(request.status.displayName).font(.headline)
                Text("We'll notify you here once a reviewer has looked at your photos.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

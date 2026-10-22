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
                    if let sources = request.sources, !sources.isEmpty { sourcesCard(sources) }
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

    private func sourcesCard(_ sources: [ReviewSource]) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("What the sources say").font(DSFont.headline).foregroundStyle(DSColor.textPrimary)
            Text("Haliable reports what published sources say. Read them and decide for yourself.")
                .font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
            ForEach(sources, id: \.self) { source in
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text("“\(source.quote)”")
                        .font(DSFont.body).italic().foregroundStyle(DSColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let url = URL(string: source.url), url.scheme == "https" || url.scheme == "http" {
                        Link(destination: url) {
                            Label("\(source.name) · Tier \(source.tier)", systemImage: "arrow.up.right.square")
                                .font(DSFont.caption)
                        }
                        .tint(DSColor.accentDeep)
                    } else {
                        Text("\(source.name) · Tier \(source.tier)").font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .cardStyle()
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

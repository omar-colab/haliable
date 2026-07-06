//
//  PendingReviewBanner.swift
//  Haliable
//
//  Phase 4 — the UNMISTAKABLE "pending scholar review" affordance.
//
//  Every grade in the app is a DRAFT until a qualified scholar signs off
//  (Final Spec §B). When the cell driving a headline verdict is still
//  `needsReview`, the screen must NOT show a confident verdict badge — it shows
//  this instead. This is deliberately loud (full-width, dashed outline, draft
//  grade demoted into a "draft" frame) so it reads as provisional at a glance,
//  not as a footnote.
//

import SwiftUI

/// Headline treatment for a verdict whose driving cell is still under review.
/// Replaces the confident `GradeBadge` at the top of `VerdictView`.
struct PendingReviewBanner: View {
    /// The draft grade we'd show if it were confirmed — surfaced, but clearly
    /// labelled as provisional.
    let draftGrade: GradeLevel

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: "hourglass.circle.fill")
                    .font(.title2)
                    .foregroundStyle(DSColor.warning)
                    .accessibilityHidden(true)
                Text("PENDING SCHOLAR REVIEW")
                    .font(DSFont.caption.weight(.heavy))
                    .kerning(0.8)
                    .foregroundStyle(DSColor.warning)
            }

            HStack(spacing: DSSpacing.xs) {
                Text("Draft grade")
                    .font(DSFont.caption.weight(.semibold))
                    .foregroundStyle(DSColor.textSecondary)
                StatusBadge(text: draftGrade.displayName,
                            systemImage: draftGrade.symbolName,
                            tint: draftGrade.tint)
                    .opacity(0.9)
            }

            Text("This grade is a draft awaiting qualified-scholar sign-off. Treat it as guidance to check the label or ask a human — not a final ruling.")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.md)
        .background(DSColor.warning.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .strokeBorder(DSColor.warning.opacity(0.55),
                              style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pending scholar review. Draft grade: \(draftGrade.displayName). Not a final ruling.")
    }
}

/// A small uppercase "DRAFT" chip for per-ingredient rows whose cell is still
/// under review, so the provisional status is unmistakable at the row level too.
struct DraftTag: View {
    var body: some View {
        Text("DRAFT")
            .font(.system(size: 9, weight: .heavy))
            .kerning(0.6)
            .foregroundStyle(DSColor.warning)
            .padding(.horizontal, DSSpacing.xxs + 1)
            .padding(.vertical, 1)
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.sm / 2, style: .continuous)
                    .strokeBorder(DSColor.warning.opacity(0.6), lineWidth: 1)
            )
            .accessibilityLabel("Draft, pending review")
    }
}

#Preview {
    VStack(spacing: DSSpacing.md) {
        PendingReviewBanner(draftGrade: .mashboohDisapproved)
        PendingReviewBanner(draftGrade: .haram)
        HStack { Text("Carmine"); DraftTag() }
    }
    .padding()
}

//
//  GradeBadge.swift
//  Haliable
//
//  Phase 4 — the 5-level counterpart to VerdictBadge. Shows a GradeLevel pill
//  (color + symbol + label from the design tokens) and, when the underlying cell
//  is still DRAFT, an hourglass marking it "pending scholar review". The 3-value
//  VerdictBadge stays in use for history/review rows that persist a `Verdict`.
//

import SwiftUI

struct GradeBadge: View {
    let grade: GradeLevel
    var pendingReview: Bool = false

    var body: some View {
        HStack(spacing: DSSpacing.xxs) {
            StatusBadge(text: grade.displayName,
                        systemImage: grade.symbolName,
                        tint: grade.tint)
            if pendingReview {
                Image(systemName: "hourglass")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .accessibilityLabel("Pending scholar review")
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        GradeBadge(grade: .halal)
        GradeBadge(grade: .mashboohSafe, pendingReview: true)
        GradeBadge(grade: .mashboohContested, pendingReview: true)
        GradeBadge(grade: .mashboohDisapproved, pendingReview: true)
        GradeBadge(grade: .haram)
    }
}

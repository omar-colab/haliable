//
//  CertificationStatusView.swift
//  Haliable
//
//  Shows how a scanned product's halal certification relates to the user's
//  chosen standard: "certified to your standard", "certified, but looser than
//  yours", "may meet your standard" (unverified mapping), or — when only a
//  generic halal label is present — "labeled halal, certifier not identified".
//
//  Renders nothing when the product carries no certification signal at all, so
//  it never adds noise to an uncertified product's verdict.
//

import SwiftUI

struct CertificationStatusView: View {
    let product: Product
    let standard: HalalStandard

    var body: some View {
        if let row = makeRow() {
            HStack(alignment: .center, spacing: DSSpacing.sm) {
                Image(systemName: row.icon)
                    .font(.title3)
                    .foregroundStyle(row.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text(row.title)
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                    Text(row.subtitle)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .surfaceStyle(fill: row.tint.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .strokeBorder(row.tint.opacity(0.35), lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(row.title). \(row.subtitle)")
        }
    }

    private struct Row {
        let icon: String
        let title: String
        let subtitle: String
        let tint: Color
    }

    private func makeRow() -> Row? {
        // Strongest signal first: a certifier on THIS product's label.
        if let body = CertificationBody.detect(in: product.labels) {
            return row(for: body, viaBrand: false)
        }

        // Weaker fallback: the product carries no certifier label, but its BRAND
        // is listed in our curated directory as certified by a known body. This
        // says nothing about the specific SKU, so we flag it brand-level and tell
        // the user to verify — the standard claim still goes through the gate.
        if let body = CertifiedBrandStore.shared.certifier(forBrand: product.brand) {
            return row(for: body, viaBrand: true)
        }

        if CertificationBody.hasGenericHalalLabel(product.labels) {
            return Row(icon: "tag.fill",
                       title: "Labeled halal",
                       subtitle: "No specific certifier was identified, so we can't compare it to \(standard.displayName). Verify on the packaging.",
                       tint: DSColor.accent)
        }

        // No certification signal at all — show nothing.
        return nil
    }

    /// Build the badge for a detected body. `viaBrand` softens every claim: a
    /// brand-directory match is not a per-product guarantee, so we name the brand
    /// caveat and never present a brand match as a confident "meets your standard".
    private func row(for body: CertificationBody, viaBrand: Bool) -> Row? {
        let brandNote = viaBrand
            ? " This is a brand-level match from our directory, not a check of this exact item — confirm the halal mark on the packaging."
            : ""
        switch StandardSatisfaction.evaluate(body: body, against: standard) {
        case .meetsYourStandard where !viaBrand:
            return Row(icon: "checkmark.seal.fill",
                       title: "Certified to your standard",
                       subtitle: "Certified by \(body.displayName) (\(body.fullName)), which meets \(standard.displayName) or stricter.",
                       tint: DSColor.success)
        case .meetsYourStandard, .pendingCitation:
            // Brand matches (even when the draft says the body satisfies) and any
            // uncited claim render as pending — same gate as a grade cell.
            return Row(icon: viaBrand ? "tag.fill" : "hourglass",
                       title: viaBrand ? "Brand listed as certified" : "Recognition pending review",
                       subtitle: "\(body.displayName) (\(body.fullName)) lists this brand as halal-certified. We don't yet have a published citation confirming it meets \(standard.displayName), so we won't claim it does.\(brandNote.isEmpty ? " Verify on the packaging." : brandNote)",
                       tint: viaBrand ? DSColor.accent : DSColor.warning)
        case .possiblyMeets:
            return Row(icon: "questionmark.seal.fill",
                       title: "May meet your standard",
                       subtitle: "Certified by \(body.displayName). Whether it satisfies \(standard.displayName) is not yet verified — check the certifier.\(brandNote)",
                       tint: DSColor.warning)
        case .looserThanYours:
            return Row(icon: "exclamationmark.triangle.fill",
                       title: "Looser than your standard",
                       subtitle: "\(body.displayName) certification doesn't meet \(standard.displayName). You may want to verify it yourself.\(brandNote)",
                       tint: DSColor.warning)
        case .unknown:
            return nil
        }
    }
}

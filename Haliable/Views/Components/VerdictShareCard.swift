//
//  VerdictShareCard.swift
//  Haliable
//
//  A 9:16 image of a verdict for sharing (Stories, group chats). It carries
//  the same honesty as the screen: a draft grade says "Pending review", the
//  standard it was graded under is named, and it says it reports sources
//  rather than ruling.
//

import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

struct VerdictShareCard: View {
    let verdict: ProductVerdict
    let standard: HalalStandard

    private var headline: String {
        verdict.overallNeedsReview ? "Pending review" : verdict.overallGrade.displayName
    }
    private var tint: Color { verdict.overallNeedsReview ? DSColor.warning : verdict.overall.tint }

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            Text("Haliable")
                .font(.custom("Spectral-Medium", size: 44))
                .foregroundStyle(DSColor.textSecondary)

            Spacer()

            VStack(alignment: .leading, spacing: 14) {
                Text(verdict.product.name)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                if let brand = verdict.product.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.system(size: 34))
                        .foregroundStyle(DSColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Text(headline)
                .font(.custom("Spectral-Medium", size: 88))
                .foregroundStyle(tint)
                .lineLimit(2)
                .minimumScaleFactor(0.5)

            if !verdict.flagged.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(verdict.flagged.prefix(4)) { item in
                        HStack(spacing: 16) {
                            Image(systemName: item.grade.symbolName).foregroundStyle(item.grade.tint)
                            Text(item.displayName).foregroundStyle(DSColor.textPrimary).lineLimit(1)
                        }
                        .font(.system(size: 36, weight: .medium))
                    }
                    if verdict.flagged.count > 4 {
                        Text("+ \(verdict.flagged.count - 4) more")
                            .font(.system(size: 30))
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Text("Graded under: \(standard.displayName)")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(DSColor.textPrimary)
                Text("Haliable reports what published halal sources say. It isn't a fatwa. Check the label yourself.")
                    .font(.system(size: 26))
                    .foregroundStyle(DSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(80)
        .frame(width: 1080, height: 1920, alignment: .topLeading)
        .background(DSColor.surface)
        .environment(\.colorScheme, .light)
    }
}

/// Renders the card only when the user actually shares.
struct VerdictShareImage: Transferable {
    let verdict: ProductVerdict
    let standard: HalalStandard

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            try await MainActor.run {
                let renderer = ImageRenderer(content: VerdictShareCard(verdict: item.verdict, standard: item.standard))
                renderer.scale = 1
                guard let data = renderer.uiImage?.pngData() else { throw CocoaError(.fileWriteUnknown) }
                return data
            }
        }
    }
}

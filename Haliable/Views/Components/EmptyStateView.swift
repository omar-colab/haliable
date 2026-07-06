//
//  EmptyStateView.swift
//  Haliable
//
//  Created by Omar O on 6/1/26.
//

import SwiftUI

// A reusable "nothing here" screen: an icon, a title, and a message.
// Used for empty history, product-not-found, no-internet, etc.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 50))
                .foregroundStyle(DSColor.textSecondary)
            Text(title)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
            Text(message)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DSSpacing.md)
    }
}

#Preview {
    EmptyStateView(
        symbol: "clock",
        title: "No scans yet",
        message: "Scan your first product on the Scan tab."
    )
}

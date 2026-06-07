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
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    EmptyStateView(
        symbol: "clock",
        title: "No scans yet",
        message: "Scan your first product on the Scan tab."
    )
}

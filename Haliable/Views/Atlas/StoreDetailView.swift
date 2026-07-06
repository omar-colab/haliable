//
//  StoreDetailView.swift
//  Haliable
//
//  Detail for one Atlas pin, with confirm/dispute actions backed by the Supabase
//  `vote_store` RPC (one vote per user; only on approved stores).
//

import SwiftUI

struct StoreDetailView: View {
    let store: Store
    let service: StoreService
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(store.category.displayName, systemImage: store.category.symbol)
                            .font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                        Spacer()
                        StatusBadge(text: store.halalScope.displayName, tint: DSColor.success)
                    }
                    Text(store.address)
                        .font(DSFont.body).foregroundStyle(DSColor.textPrimary)
                    Text("\(store.city), \(store.state) \(store.zip)")
                        .font(DSFont.body).foregroundStyle(DSColor.textSecondary)

                    if !store.certifications.isEmpty {
                        Text("Certifications: " + store.certifications.joined(separator: ", "))
                            .font(DSFont.body)
                    }

                    Label("\(store.confirmCount) confirmations · \(store.disputeCount) disputes",
                          systemImage: "person.2.fill")
                        .font(DSFont.caption).foregroundStyle(DSColor.textSecondary)

                    Divider()

                    HStack {
                        Button { Task { await act(confirm: true) } } label: {
                            Label("Still halal", systemImage: "checkmark").frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent).tint(DSColor.success)
                        Button { Task { await act(confirm: false) } } label: {
                            Label("Report issue", systemImage: "flag").frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered).tint(DSColor.danger)
                    }

                    if let message {
                        Text(message).font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                    }
                }
                .padding()
            }
            .navigationTitle(store.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private func act(confirm: Bool) async {
        guard auth.isSignedIn else { message = "Sign in (on the Reviews tab) to vote."; return }
        do {
            let result = confirm ? try await service.confirm(store, auth: auth)
                                 : try await service.dispute(store, auth: auth)
            message = "Thanks — recorded. \(result.confirmCount) confirmations · \(result.disputeCount) disputes."
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

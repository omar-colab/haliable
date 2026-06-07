//
//  StoreDetailView.swift
//  Haliable
//
//  Detail for one Atlas pin, with confirm/dispute actions. SCAFFOLD — the
//  confirm/dispute calls hit StoreService stubs until the backend exists.
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
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text(store.halalScope.displayName)
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.green.opacity(0.15)).foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    Text(store.address)
                    Text("\(store.city), \(store.state) \(store.zip)").foregroundStyle(.secondary)

                    if !store.certifications.isEmpty {
                        Text("Certifications: " + store.certifications.joined(separator: ", "))
                            .font(.callout)
                    }

                    Label("\(store.confirmCount) confirmations · \(store.disputeCount) disputes",
                          systemImage: "person.2.fill")
                        .font(.caption).foregroundStyle(.secondary)

                    Divider()

                    HStack {
                        Button { Task { await act(confirm: true) } } label: {
                            Label("Still halal", systemImage: "checkmark").frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent).tint(.green)
                        Button { Task { await act(confirm: false) } } label: {
                            Label("Report issue", systemImage: "flag").frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered).tint(.red)
                    }

                    if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
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
            if confirm { try await service.confirm(store, auth: auth) }
            else { try await service.dispute(store, auth: auth) }
            message = "Thanks — recorded. (Backend pending.)"
        } catch { message = error.localizedDescription }
    }
}

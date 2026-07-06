//
//  SubmitStoreView.swift
//  Haliable
//
//  Community store submission form. SCAFFOLD — submits to a StoreService stub
//  (adds a local pending pin) until the Atlas backend is wired up.
//

import SwiftUI
import CoreLocation

struct SubmitStoreView: View {
    let service: StoreService
    let center: CLLocationCoordinate2D

    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var draft: StoreDraft
    @State private var errorMessage: String?

    init(service: StoreService, center: CLLocationCoordinate2D) {
        self.service = service
        self.center = center
        _draft = State(initialValue: StoreDraft(coordinate: center))
    }

    var body: some View {
        NavigationStack {
            Form {
                if !auth.isSignedIn {
                    Section {
                        Text("Sign in with Apple to add a place.")
                            .font(DSFont.body).foregroundStyle(DSColor.textSecondary)
                        AppleSignInButton { errorMessage = $0 }
                    }
                } else {
                    Section("Place") {
                        TextField("Name", text: $draft.name)
                        Picker("Category", selection: $draft.category) {
                            ForEach(StoreCategory.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        Picker("Halal scope", selection: $draft.halalScope) {
                            Text("Fully halal").tag(HalalScope.fullyHalal)
                            Text("Halal meat only").tag(HalalScope.halalMeatOnly)
                            Text("Halal options").tag(HalalScope.halalOptions)
                            Text("Unverified").tag(HalalScope.unverified)
                        }
                    }
                    Section("Address") {
                        TextField("Street", text: $draft.address)
                        TextField("City", text: $draft.city)
                        TextField("State (2-letter)", text: $draft.state)
                        TextField("ZIP", text: $draft.zip).keyboardType(.numberPad)
                    }
                    Section {
                        Button("Submit place") { Task { await submit() } }
                            .disabled(draft.name.count < 2)
                        Text("New places are pending until the community confirms them.")
                            .font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).font(DSFont.body).foregroundStyle(DSColor.danger) }
                }
            }
            .navigationTitle("Add a Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private func submit() async {
        errorMessage = nil
        do { try await service.submit(draft, auth: auth); dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
}

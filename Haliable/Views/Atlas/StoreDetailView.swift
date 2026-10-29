//
//  StoreDetailView.swift
//  Haliable
//
//  Board screen 6 — one Atlas place: why it's listed, where the data came from,
//  and community confirm/dispute backed by the Supabase `vote_store` RPC (one
//  vote per user; only on approved stores). No opening hours: the data has none,
//  so the board's "open until 9pm" is deliberately absent.
//

import SwiftUI
import MapKit

struct StoreDetailView: View {
    let store: Store
    let service: StoreService
    @Environment(AuthManager.self) private var auth
    @State private var message: String?
    @State private var asking = false
    @State private var confirms: Int
    @State private var disputes: Int
    @State private var placeCard: MKMapItem?
    @State private var findingCard = false
    @State private var cardMissing = false

    init(store: Store, service: StoreService) {
        self.store = store
        self.service = service
        _confirms = State(initialValue: store.confirmCount)
        _disputes = State(initialValue: store.disputeCount)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.name)
                        .font(.system(size: 22, weight: .heavy))
                        .tracking(-0.6)
                        .foregroundStyle(DSColor.textPrimary)
                    Text([store.category.displayName, store.distanceText].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 12.5))
                        .foregroundStyle(DSColor.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .padding(.bottom, DSSpacing.xs)

                chips.padding(.bottom, DSSpacing.xxs)

                // Unverified must not wear the green check that verified places get.
                GuardRow(symbol: store.halalScope == .unverified ? "questionmark.circle" : "checkmark.circle",
                         tint: store.halalScope == .fullyHalal || store.halalScope == .halalMeatOnly
                            ? DSColor.success : DSColor.warning,
                         title: store.halalScope.displayName,
                         subtitle: store.external.map { "\($0.claim) — not verified by Haliable. Ask before you order." }
                            ?? (store.certifications.isEmpty
                                ? "Listed on Haliable"
                                : "Certified: " + store.certifications.joined(separator: ", ")),
                         showsArrow: false, subtitleLines: 3)

                GuardRow(symbol: "mappin.and.ellipse",
                         tint: DSColor.textPrimary,
                         title: store.address,
                         subtitle: ([store.city, store.state].filter { !$0.isEmpty }.joined(separator: ", ") + " · "
                                    + (store.external?.name ?? "Haliable")).trimmingCharacters(in: CharacterSet(charactersIn: " ·"))) {
                    openInMaps()
                }

                GuardAction(symbol: "menucard",
                            title: findingCard ? "Opening Apple Maps…" : "Menu, hours & photos",
                            subtitle: cardMissing ? "Apple Maps doesn't have this place yet."
                                                  : "Apple Maps place card · check the menu before you order") {
                    Task { await openPlaceCard() }
                }
                .disabled(findingCard)
                .padding(.top, DSSpacing.xs)

                if !store.isExternal {
                GuardAction(symbol: "checkmark.circle",
                            title: "Still accurate?",
                            subtitle: "Confirm or dispute what's listed here.") {
                    asking = true
                }
                .padding(.top, DSSpacing.xs)

                Text(message ?? "\(confirms) confirmed · \(disputes) disputed by the community")
                    .font(.system(size: 11.5))
                    .foregroundStyle(DSColor.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, DSSpacing.xxs)
                }
            }
            .padding(.horizontal, DSSpacing.screen)
            .padding(.top, DSSpacing.lg)
            .padding(.bottom, DSSpacing.lg)
        }
        .background(DSColor.surface)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .presentationBackground(DSColor.surface)
        .mapItemDetailSheet(item: $placeCard)
        .confirmationDialog("Is this listing still accurate?", isPresented: $asking, titleVisibility: .visible) {
            Button("Yes — still accurate") { Task { await act(confirm: true) } }
            Button("No — report an issue", role: .destructive) { Task { await act(confirm: false) } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var chips: some View {
        HStack(spacing: 5) {
            chip(store.halalScope.displayName, on: store.halalScope != .unverified)
            if store.status == .approved { chip("Verified", on: false) }
            // Apple Maps / OSM places can't be voted on, so "0 confirms" says nothing.
            if !store.isExternal { chip(confirms == 1 ? "1 confirm" : "\(confirms) confirms", on: false) }
        }
    }

    private func chip(_ text: String, on: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(on ? AnyShapeStyle(LinearGradient(colors: [DSColor.accent, DSColor.accentGradientEnd],
                                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                           : AnyShapeStyle(DSColor.surfaceElevated), in: Capsule())
            .overlay(Capsule().strokeBorder(on ? .clear : DSColor.outline, lineWidth: 1))
            .foregroundStyle(on ? .white : DSColor.textSecondary)
    }

    private func openPlaceCard() async {
        findingCard = true
        defer { findingCard = false }
        placeCard = await service.appleMapItem(for: store)
        cardMissing = placeCard == nil
    }

    private func openInMaps() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: store.coordinate))
        item.name = store.name
        item.openInMaps()
    }

    private func act(confirm: Bool) async {
        guard auth.isSignedIn else { message = "Sign in on the Reviews tab to vote."; return }
        do {
            let result = confirm ? try await service.confirm(store, auth: auth)
                                 : try await service.dispute(store, auth: auth)
            confirms = result.confirmCount
            disputes = result.disputeCount
            message = "Thanks — recorded. \(result.confirmCount) confirmed · \(result.disputeCount) disputed."
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

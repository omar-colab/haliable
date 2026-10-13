//
//  AtlasV2.swift
//  Haliable
//
//  Redesigned "Find" tab on the holistic app look. Same MapKit data and logic as
//  AtlasView (StoreService seed, LocationManager, submit sheet) — re-skinned with
//  the shared header, ambient glow, and card/chip styling so it matches every
//  other V2 screen. Original AtlasView is untouched.
//
//  Preview swap: in RootTabView.swift, change `AtlasView()` to `AtlasV2()`.
//

import SwiftUI
import MapKit

struct AtlasV2: View {
    @Environment(AuthManager.self) private var auth
    @State private var stores = StoreService()
    @State private var location = LocationManager()
    @State private var camera: MapCameraPosition = .automatic
    @State private var selected: Store?
    @State private var showSubmit = false

    // Fallback center until we have a fix (so the map is never blank).
    private let fallback = CLLocationCoordinate2D.atlasFallback

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                map
                    .ignoresSafeArea(edges: .bottom)

                // Legibility scrim so the header reads over any map tile.
                LinearGradient(
                    colors: [DSColor.background.opacity(0.92), DSColor.background.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 180)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)

                AppScreenHeader(eyebrow: "NEAR YOU", title: "Find", titleAccent: " Halal", trailing: {})
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.top, DSSpacing.sm)

                controls
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selected) { store in
                StoreDetailView(store: store, service: stores)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSubmit) {
                SubmitStoreView(service: stores,
                                center: location.coordinate ?? fallback)
            }
            .task { await begin() }
            .onChange(of: location.coordinate?.latitude) { _, _ in
                Task { await refreshAtUser() }
            }
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $camera, selection: $selected) {
            UserAnnotation()
            ForEach(stores.stores) { store in
                Marker(store.name, systemImage: store.category.symbol, coordinate: store.coordinate)
                    .tint(tint(for: store.halalScope))
                    .tag(store)
            }
        }
        .mapControls { MapUserLocationButton(); MapCompass() }
    }

    // MARK: - Floating controls

    private var controls: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                legend
                Spacer()
                Button { showSubmit = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .frame(width: 56, height: 56)
                        .background(DSColor.accent, in: Circle())
                        .foregroundStyle(DSColor.onAccent)
                        .overlay(Circle().strokeBorder(DSColor.accent.opacity(0.4), lineWidth: 6))
                        .shadow(color: DSColor.accent.opacity(0.5), radius: 12, y: 4)
                }
                .accessibilityLabel("Add a halal place")
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.bottom, DSSpacing.md)

            if stores.isLoading {
                Label("Finding halal places near you…", systemImage: "location.magnifyingglass")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.sm)
                    .background(DSColor.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(DSColor.outline.opacity(0.5), lineWidth: 1))
                    .padding(.bottom, DSSpacing.lg)
            }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            legendRow(DSColor.success, "Fully halal")
            legendRow(.teal, "Halal meat")
            legendRow(DSColor.warning, "Halal options")
        }
        .padding(DSSpacing.sm)
        .background(DSColor.surface.opacity(0.95), in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                .strokeBorder(DSColor.outline.opacity(0.5), lineWidth: 1)
        )
    }

    private func legendRow(_ color: Color, _ label: String) -> some View {
        HStack(spacing: DSSpacing.xs) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
    }

    // MARK: - Logic (identical to AtlasView)

    private func begin() async {
        location.request()
        let center = location.coordinate ?? fallback
        camera = .region(MKCoordinateRegion(center: center,
                          span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
        await stores.loadNearby(center: center)
    }

    private func refreshAtUser() async {
        guard let c = location.coordinate else { return }
        camera = .region(MKCoordinateRegion(center: c,
                          span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
        await stores.loadNearby(center: c)
    }

    private func tint(for scope: HalalScope) -> Color {
        switch scope {
        case .fullyHalal:    return DSColor.success
        case .halalMeatOnly: return .teal               // distinct hue; no semantic token
        case .halalOptions:  return DSColor.warning
        case .unverified:    return DSColor.textSecondary
        }
    }
}

#Preview {
    AtlasV2()
        .environment(AuthManager())
        .preferredColorScheme(.dark)
}

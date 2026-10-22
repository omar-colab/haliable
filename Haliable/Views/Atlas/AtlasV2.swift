//
//  AtlasV2.swift
//  Haliable
//
//  Board screen 5 — the Find tab. Real pins from StoreService (live Supabase,
//  never invented offline), drawn as capsule labels, plus a list panel with the
//  board's scope filters. "Real halal places near campus" reads harder as a list
//  than as five dots, so the list is open by default.
//

import SwiftUI
import MapKit

struct AtlasV2: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppSettings.self) private var settings
    @State private var stores = StoreService()
    @State private var location = LocationManager()
    @State private var camera: MapCameraPosition = .automatic
    @State private var selected: Store?
    @State private var showSubmit = false
    @State private var filter: ScopeFilter = .all
    @State private var listOpen = true
    @State private var appleSearch: Task<Void, Never>?

    private let fallback = CLLocationCoordinate2D.atlasFallback

    enum ScopeFilter: Hashable {
        case all, fullyHalal, meat, options

        func admits(_ scope: HalalScope) -> Bool {
            switch self {
            case .all:        return true
            case .fullyHalal: return scope == .fullyHalal
            case .meat:       return scope == .halalMeatOnly
            case .options:    return scope == .halalOptions
            }
        }
    }

    private var visible: [Store] {
        (stores.stores + stores.appleStores)
            .filter { filter.admits($0.halalScope) }
            .sorted { ($0.distanceM ?? .greatestFiniteMagnitude) < ($1.distanceM ?? .greatestFiniteMagnitude) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                map.ignoresSafeArea()

                VStack(spacing: DSSpacing.sm) {
                    topBar
                    Spacer(minLength: 0)
                    statusChip
                    listPanel
                }
                .padding(.horizontal, DSSpacing.screen)
                // The map ignores the safe area, and the dock's inset doesn't reach
                // this overlay on device; clear the dock explicitly.
                .padding(.bottom, 78)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selected) { store in
                StoreDetailView(store: store, service: stores)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSubmit) {
                SubmitStoreView(service: stores, center: location.coordinate ?? fallback)
            }
            .task { await begin() }
            .onChange(of: location.coordinate?.latitude) { _, _ in
                Task { await refreshAtUser() }
            }
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $camera) {
            UserAnnotation()
            ForEach(visible) { store in
                Annotation(store.name, coordinate: store.coordinate, anchor: .bottom) {
                    pin(store)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        // Wherever the map is pointed, load verified places and Apple Maps results there.
        .onMapCameraChange(frequency: .onEnd) { ctx in
            appleSearch?.cancel()
            appleSearch = Task { await stores.loadVisible(ctx.region, user: location.coordinate) }
        }
    }

    private func pin(_ store: Store) -> some View {
        let on = selected?.id == store.id
        return Button { selected = store } label: {
            HStack(spacing: 5) {
                Image(systemName: store.category.symbol)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 17, height: 17)
                    .background(on ? AnyShapeStyle(.white.opacity(0.26))
                                   : AnyShapeStyle(LinearGradient(colors: [DSColor.accent, DSColor.accentGradientEnd],
                                                                  startPoint: .topLeading, endPoint: .bottomTrailing)),
                                in: Circle())
                Text(store.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(on ? .white : DSColor.textPrimary)
                    .lineLimit(1)
            }
            .padding(.leading, 5)
            .padding(.trailing, 10)
            .padding(.vertical, 5)
            .background {
                if on {
                    Capsule().fill(LinearGradient(colors: [DSColor.accent, DSColor.accentGradientEnd],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    Capsule().fill(DSColor.surface.opacity(0.95))
                }
            }
            .overlay(Capsule().strokeBorder(on ? .clear : DSColor.outlineStrong, lineWidth: 1))
            .shadow(color: on ? DSColor.accent.opacity(0.45) : .black.opacity(0.18), radius: 8, y: 3)
        }
        .pressable(0.94)
        .accessibilityLabel("\(store.name), \(store.halalScope.displayName)")
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack(spacing: 6) {
            GuardChip(text: areaName, live: !stores.stores.isEmpty)
            Spacer(minLength: 0)
            RingButton(symbol: "location", label: "Centre on me") { Task { await refreshAtUser() } }
            RingButton(symbol: "plus", label: "Add a halal place") { showSubmit = true }
        }
        .padding(.top, DSSpacing.xs)
    }

    private var areaName: String {
        if let city = stores.stores.first?.city, !city.isEmpty {
            return city == "Storrs" ? "UConn Storrs" : city
        }
        return "Near you"
    }

    @ViewBuilder private var statusChip: some View {
        if stores.isLoading {
            GuardChip(text: "Finding halal places near you…")
        } else if let message = stores.lastError {
            GuardChip(text: message)
        }
    }

    private var listPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            Capsule().fill(DSColor.textTertiary.opacity(0.55))
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            GuardSegments(options: [(ScopeFilter.all, "All"), (.fullyHalal, "Fully halal"),
                                    (.meat, "Meat"), (.options, "Options")],
                          selection: $filter)

            GuardSection(title: visible.count == 1 ? "1 place near you" : "\(visible.count) places near you",
                         trailing: listOpen ? "Map" : "List") {
                withAnimation(DSMotion.sheet) { listOpen.toggle() }
            }

            if listOpen {
                if visible.isEmpty {
                    Text(stores.isLoading ? "Loading…" : "No places match this filter yet.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(DSColor.textSecondary)
                        .padding(.vertical, DSSpacing.xs)
                } else {
                    ScrollView {
                        VStack(spacing: DSSpacing.xs) {
                            ForEach(visible) { store in
                                GuardRow(symbol: store.category.symbol,
                                         tint: tint(for: store.halalScope),
                                         title: store.name,
                                         subtitle: rowDetail(store)) {
                                    selected = store
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 230)
                    .scrollIndicators(.hidden)
                }
                Text("Locations © OpenStreetMap contributors (ODbL) · grey pins: Apple Maps, not verified")
                    .font(.system(size: 9.5))
                    .foregroundStyle(DSColor.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.top, 10)
        .padding(.bottom, DSSpacing.sm)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(DSColor.outline, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 20, y: -6)
    }

    private func rowDetail(_ store: Store) -> String {
        [store.isAppleMaps ? "Apple Maps · not verified" : store.halalScope.displayName.lowercased(), store.distanceText].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: - Logic

    /// Frames the Settings search radius (1° latitude ≈ 111 km).
    private var radiusSpan: MKCoordinateSpan {
        let deg = settings.searchRadiusKm * 2 / 111
        return MKCoordinateSpan(latitudeDelta: deg, longitudeDelta: deg)
    }

    private func begin() async {
        location.request()
        let center = location.coordinate ?? fallback
        camera = .region(MKCoordinateRegion(center: center,
                          span: radiusSpan))
        await stores.loadNearby(center: center, radiusKm: settings.searchRadiusKm)
    }

    private func refreshAtUser() async {
        guard let c = location.coordinate else { return }
        withAnimation {
            camera = .region(MKCoordinateRegion(center: c,
                              span: radiusSpan))
        }
        await stores.loadNearby(center: c, radiusKm: settings.searchRadiusKm)
    }

    private func tint(for scope: HalalScope) -> Color {
        switch scope {
        case .fullyHalal, .halalMeatOnly: return DSColor.success
        case .halalOptions:               return DSColor.warning
        case .unverified:                 return DSColor.textSecondary
        }
    }
}

extension Store {
    /// "0.3 mi", or nil when the server didn't return a distance.
    var distanceText: String? {
        guard let m = distanceM else { return nil }
        let miles = m / 1609.344
        return miles < 0.1 ? "nearby" : String(format: "%.1f mi", miles)
    }
}

#Preview {
    AtlasV2()
        .environment(AuthManager())
        .environment(AppSettings())
}

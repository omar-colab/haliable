//
//  AtlasV2.swift
//  Haliable
//
//  Board screen 5 — the Find tab, Connecticut only: the verified Atlas places
//  (live Supabase) plus the bundled Connecticut list, each with its own menu.
//  Drawn as capsule labels, plus a list panel sorted by distance from you.
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
    @State private var filter: ScopeFilter = .all
    @State private var listOpen = false
    /// What the map is showing right now (nil until the first camera settle).
    @State private var region: MKCoordinateRegion?
    /// Places too close together to split by zooming (one building) — pick from a list.
    @State private var stacked: [Store] = []
    /// Centre on the person once, at the first GPS fix; after that the map stays where they put it.
    @State private var centeredOnUser = false

    private let fallback = CLLocationCoordinate2D.atlasFallback

    enum ScopeFilter: Hashable {
        case all, food, groceries, verified

        func admits(_ store: Store) -> Bool {
            switch self {
            case .all:       return true
            case .food:      return [.restaurant, .cafe, .bakery].contains(store.category)
            case .groceries: return [.grocery, .supermarket, .butcher].contains(store.category)
            case .verified:  return !store.isExternal
            }
        }
    }

    /// Connecticut, with a little sea and border around it. The camera can't leave it.
    static let connecticut = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 41.52, longitude: -72.76),
                                                span: MKCoordinateSpan(latitudeDelta: 1.25, longitudeDelta: 2.1))

    private var visible: [Store] {
        stores.places(near: location.coordinate)
            .filter { filter.admits($0) && inView($0.coordinate) }
            .sorted { ($0.distanceM ?? .greatestFiniteMagnitude) < ($1.distanceM ?? .greatestFiniteMagnitude) }
    }

    private var userInConnecticut: Bool {
        guard let c = location.coordinate else { return true }
        let r = Self.connecticut
        return abs(c.latitude - r.center.latitude) <= r.span.latitudeDelta / 2
            && abs(c.longitude - r.center.longitude) <= r.span.longitudeDelta / 2
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
            .confirmationDialog("\(stacked.count) places here",
                                isPresented: Binding(get: { !stacked.isEmpty }, set: { if !$0 { stacked = [] } }),
                                titleVisibility: .visible) {
                ForEach(stacked) { store in
                    Button(store.name) { selected = store }
                }
            }
            .sheet(item: $selected) { store in
                StoreDetailView(store: store, service: stores)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSubmit) {
                SubmitStoreView(service: stores, center: location.coordinate ?? fallback)
            }
            .task { await begin() }
            .onChange(of: location.coordinate?.latitude) { _, _ in
                guard !centeredOnUser else { return }
                centeredOnUser = true
                Task { await refreshAtUser() }
            }
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $camera,
            bounds: MapCameraBounds(centerCoordinateBounds: Self.connecticut,
                                    minimumDistance: 400, maximumDistance: 400_000)) {
            UserAnnotation()
            ForEach(clusters) { c in
                Annotation(c.stores[0].name, coordinate: c.coordinate, anchor: .bottom) {
                    if c.stores.count == 1 { pin(c.stores[0]) } else { clusterBubble(c) }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .onMapCameraChange(frequency: .onEnd) { ctx in region = ctx.region }
    }

    // MARK: - Clustering

    struct Cluster: Identifiable {
        let stores: [Store]
        var id: UUID { stores[0].id }
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: stores.map(\.coordinate.latitude).reduce(0, +) / Double(stores.count),
                                   longitude: stores.map(\.coordinate.longitude).reduce(0, +) / Double(stores.count))
        }
    }

    /// Pins that would overlap on screen merge into one bubble. A pin with its
    /// name is wide and short, so the grid cell is too: about a third of the
    /// screen across and a twentieth down.
    // ponytail: fixed grid, so two pins either side of a cell edge can still touch; distance-based clustering if that shows up.
    private var clusters: [Cluster] {
        guard let r = region else { return visible.map { Cluster(stores: [$0]) } }
        let cellLat = r.span.latitudeDelta / 20, cellLng = r.span.longitudeDelta / 3
        var cells: [String: [Store]] = [:]
        for store in visible {
            let key = "\(Int(floor(store.coordinate.latitude / cellLat))):\(Int(floor(store.coordinate.longitude / cellLng)))"
            cells[key, default: []].append(store)
        }
        return cells.values.map { Cluster(stores: $0) }
    }

    private func clusterBubble(_ c: Cluster) -> some View {
        let verified = c.stores.contains { !$0.isExternal }
        return Button { open(c) } label: {
            Text("\(c.stores.count)")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white)
                .frame(minWidth: 34, minHeight: 34)
                .background(verified ? AnyShapeStyle(LinearGradient(colors: [DSColor.accent, DSColor.accentGradientEnd],
                                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                     : AnyShapeStyle(DSColor.textSecondary), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .pressable(0.94)
        .accessibilityLabel("\(c.stores.count) halal places here. Double-tap to show them.")
    }

    /// Zoom in until the bubble splits; if they share one spot, list them instead.
    private func open(_ c: Cluster) {
        let lats = c.stores.map(\.coordinate.latitude), lngs = c.stores.map(\.coordinate.longitude)
        let spread = max(lats.max()! - lats.min()!, lngs.max()! - lngs.min()!)
        guard let r = region, spread > 0.0004 else { stacked = c.stores; return }
        withAnimation(.easeInOut(duration: 0.35)) {
            camera = .region(MKCoordinateRegion(center: c.coordinate,
                                                span: MKCoordinateSpan(latitudeDelta: max(r.span.latitudeDelta / 4, spread * 3),
                                                                       longitudeDelta: max(r.span.longitudeDelta / 4, spread * 3))))
        }
    }

    private func inView(_ c: CLLocationCoordinate2D) -> Bool {
        guard let r = region else { return true }
        return abs(c.latitude - r.center.latitude) <= r.span.latitudeDelta / 2
            && abs(c.longitude - r.center.longitude) <= r.span.longitudeDelta / 2
    }

    private func pin(_ store: Store) -> some View {
        let on = selected?.id == store.id
        let fill = store.isExternal ? [DSColor.textSecondary, DSColor.textSecondary]
                                     : [DSColor.accent, DSColor.accentGradientEnd]
        return Button { selected = store } label: {
            HStack(spacing: 5) {
                Image(systemName: store.category.symbol)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 17, height: 17)
                    .background(on ? AnyShapeStyle(.white.opacity(0.26))
                                   : AnyShapeStyle(LinearGradient(colors: fill,
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
                    Capsule().fill(LinearGradient(colors: fill,
                                                  startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    Capsule().fill(DSColor.surface.opacity(0.95))
                }
            }
            .overlay(Capsule().strokeBorder(on ? .clear : DSColor.outlineStrong, lineWidth: 1))
            .shadow(color: on ? DSColor.accent.opacity(0.45) : .black.opacity(0.18), radius: 8, y: 3)
        }
        .pressable(0.94)
        .accessibilityLabel(store.isExternal ? "\(store.name), \(store.external?.name ?? "") result, not verified"
                                                : "\(store.name), \(store.halalScope.displayName)")
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack(spacing: 6) {
            GuardChip(text: "Halal places in Connecticut", live: !visible.isEmpty)
            Spacer(minLength: 0)
            RingButton(symbol: "location", label: "Centre on me") { Task { await refreshAtUser() } }
            RingButton(symbol: "plus", label: "Add a halal place") { showSubmit = true }
        }
        .padding(.top, DSSpacing.xs)
    }

    @ViewBuilder private var statusChip: some View {
        if !userInConnecticut {
            GuardChip(text: "Haliable's map covers Connecticut only")
        }
    }

    private var listPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            Capsule().fill(DSColor.textTertiary.opacity(0.55))
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            GuardSegments(options: [(ScopeFilter.all, "All"), (.food, "Food"),
                                    (.groceries, "Groceries"), (.verified, "Verified")],
                          selection: $filter)

            GuardSection(title: visible.count == 1 ? "1 place in view" : "\(visible.count) places in view",
                         trailing: listOpen ? "Map" : "List") {
                withAnimation(DSMotion.sheet) { listOpen.toggle() }
            }

            if listOpen {
                if visible.isEmpty {
                    Text("No places here match this filter. Zoom out or pick All.")
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
                Text("Grey pins: listed as halal on Apple Maps or OpenStreetMap (© contributors, ODbL), checked Oct 2026 — not verified by Haliable. Ask before you order.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(DSColor.textTertiary)
                    .multilineTextAlignment(.center)
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
        [store.isExternal ? store.city : store.halalScope.displayName,
         store.distanceText,
         store.menuURL == nil ? nil : "menu"].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    // MARK: - Logic

    /// Opens on the person (Storrs if they're outside Connecticut), zoomed out just
    /// far enough to take in the eight places nearest them.
    private var home: CLLocationCoordinate2D {
        userInConnecticut ? location.coordinate ?? fallback : fallback
    }

    private var nearbyRegion: MKCoordinateRegion {
        let c = home
        let nearest = stores.places(near: c)
            .sorted { ($0.distanceM ?? 0) < ($1.distanceM ?? 0) }
            .prefix(8)
        let reach = nearest.map { max(abs($0.lat - c.latitude), abs($0.lng - c.longitude) * 0.75) }.max() ?? 0.05
        let lat = min(max(reach * 2.4, 0.04), 1.2)
        return MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: lat, longitudeDelta: lat / 0.75))
    }

    private func begin() async {
        location.request()
        camera = .region(nearbyRegion)
        // The verified places: one load covers the whole state.
        await stores.loadNearby(center: Self.connecticut.center, radiusKm: 150)
        withAnimation { camera = .region(nearbyRegion) }
    }

    private func refreshAtUser() async {
        withAnimation { camera = .region(nearbyRegion) }
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

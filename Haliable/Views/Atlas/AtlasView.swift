//
//  AtlasView.swift
//  Haliable
//
//  The "Find" tab: a MapKit map of halal places near the user. SCAFFOLD — pins
//  come from StoreService's seeded data until the Atlas backend is built.
//

import SwiftUI
import MapKit

struct AtlasView: View {
    @Environment(AuthManager.self) private var auth
    @State private var stores = StoreService()
    @State private var location = LocationManager()
    @State private var camera: MapCameraPosition = .automatic
    @State private var selected: Store?
    @State private var showSubmit = false

    // Fallback center until we have a fix (so the map is never blank).
    private let fallback = CLLocationCoordinate2D(latitude: 40.7308, longitude: -73.9975)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Map(position: $camera, selection: $selected) {
                    UserAnnotation()
                    ForEach(stores.stores) { store in
                        Marker(store.name, systemImage: store.category.symbol, coordinate: store.coordinate)
                            .tint(tint(for: store.halalScope))
                            .tag(store)
                    }
                }
                .mapControls { MapUserLocationButton(); MapCompass() }

                if stores.isLoading {
                    ProgressView("Finding halal places near you…")
                        .padding().background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 90)
                }

                Button { showSubmit = true } label: {
                    Image(systemName: "plus").font(.title2.bold())
                        .frame(width: 56, height: 56)
                        .background(.green, in: Circle())
                        .foregroundStyle(.white).shadow(radius: 4)
                }
                .padding()
            }
            .navigationTitle("Find Halal")
            .navigationBarTitleDisplayMode(.inline)
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
        case .fullyHalal:    return .green
        case .halalMeatOnly: return .teal
        case .halalOptions:  return Color(red: 0.71, green: 0.52, blue: 0.16)
        case .unverified:    return .gray
        }
    }
}

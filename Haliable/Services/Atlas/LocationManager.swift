//
//  LocationManager.swift
//  Haliable
//
//  One-shot location for the Atlas "find near me" flow. Requests when-in-use
//  permission and publishes the latest coordinate. Kept deliberately small.
//

import Foundation
import CoreLocation
import Observation

extension CLLocationCoordinate2D {
    /// Where the Atlas opens when there's no location yet — permission denied, the user
    /// hasn't answered the prompt, or a simulator with no location set (which is what a
    /// demo looks like). Central Connecticut, so the map frames the seeded stores rather
    /// than an empty ocean of map tiles.
    ///
    /// Lived in both AtlasView and AtlasV2 as the same hardcoded NYC pair; one constant
    /// now, so moving it is a one-line change.
    static let atlasFallback = CLLocationCoordinate2D(latitude: 41.7637, longitude: -72.6851)
}

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var coordinate: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var didDeny = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            didDeny = true
        @unknown default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            didDeny = true
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last { coordinate = loc.coordinate }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep the seeded fallback; the Atlas still renders.
    }
}

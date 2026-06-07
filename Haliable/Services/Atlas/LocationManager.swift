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

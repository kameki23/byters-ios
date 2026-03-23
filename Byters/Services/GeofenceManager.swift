import Foundation
import CoreLocation
import SwiftUI

// MARK: - GeofenceResult

enum GeofenceResult {
    case withinRange(distance: Double)
    case outOfRange(distance: Double)
    case locationUnavailable
    case permissionDenied
}

// MARK: - GeofenceManager

@MainActor
class GeofenceManager: NSObject, ObservableObject {
    static let shared = GeofenceManager()

    @Published var currentLocation: CLLocation?
    @Published var isWithinWorkArea: Bool = false
    @Published var distanceToWorkLocation: Double?

    private let locationManager = CLLocationManager()
    private var monitoredCoordinate: CLLocationCoordinate2D?
    private var monitoredRadius: Double = 200

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
    }

    // MARK: - Public Methods

    func startMonitoring(latitude: Double, longitude: Double, radius: Double = 200) {
        monitoredCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        monitoredRadius = radius

        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
            locationManager.startUpdatingLocation()
            registerGeofenceRegion()
        case .authorizedAlways:
            locationManager.startUpdatingLocation()
            registerGeofenceRegion()
        default:
            break
        }
    }

    func stopMonitoring() {
        locationManager.stopUpdatingLocation()

        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }

        monitoredCoordinate = nil
        isWithinWorkArea = false
        distanceToWorkLocation = nil
    }

    func validateLocation(jobLatitude: Double, jobLongitude: Double, radius: Double = 200) -> GeofenceResult {
        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return .permissionDenied
        }

        guard let current = currentLocation else {
            return .locationUnavailable
        }

        let jobLocation = CLLocation(latitude: jobLatitude, longitude: jobLongitude)
        let distance = current.distance(from: jobLocation)

        if distance <= radius {
            return .withinRange(distance: distance)
        } else {
            return .outOfRange(distance: distance)
        }
    }

    // MARK: - Private Methods

    private func registerGeofenceRegion() {
        guard let coordinate = monitoredCoordinate else { return }
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            #if DEBUG
            print("[Geofence] ジオフェンス監視がサポートされていません")
            #endif
            return
        }

        // Remove existing regions
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }

        let region = CLCircularRegion(
            center: coordinate,
            radius: min(monitoredRadius, locationManager.maximumRegionMonitoringDistance),
            identifier: "work_location"
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true

        locationManager.startMonitoring(for: region)
    }

    private func updateDistanceAndStatus() {
        guard let current = currentLocation, let coordinate = monitoredCoordinate else {
            distanceToWorkLocation = nil
            isWithinWorkArea = false
            return
        }

        let workLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = current.distance(from: workLocation)
        distanceToWorkLocation = distance
        isWithinWorkArea = distance <= monitoredRadius
    }
}

// MARK: - CLLocationManagerDelegate

extension GeofenceManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            currentLocation = location
            updateDistanceAndStatus()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if monitoredCoordinate != nil {
                    locationManager.startUpdatingLocation()
                    registerGeofenceRegion()
                }
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == "work_location" else { return }
        Task { @MainActor in
            isWithinWorkArea = true
            #if DEBUG
            print("[Geofence] 勤務エリアに入りました")
            #endif
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == "work_location" else { return }
        Task { @MainActor in
            isWithinWorkArea = false
            #if DEBUG
            print("[Geofence] 勤務エリアから出ました")
            #endif
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        #if DEBUG
        print("[Geofence] 監視エラー: \(error.localizedDescription)")
        #endif
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("[Geofence] 位置情報エラー: \(error.localizedDescription)")
        #endif
    }
}

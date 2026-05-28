//
//  LocationCaptureService.swift
//  Kubb Coach
//
//  One-shot location capture for session Conditions snapshot. Wraps
//  CLLocationManager with an async API and reverse-geocodes to a
//  "Town, Region" string for display.
//

import Foundation
import CoreLocation
import OSLog

@MainActor
final class LocationCaptureService: NSObject {
    static let shared = LocationCaptureService()

    struct CapturedPlace {
        let coordinate: CLLocationCoordinate2D
        let displayName: String  // e.g. "Stockholm, SE"
    }

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var pendingAuth: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var pendingLocation: CheckedContinuation<CLLocation?, Never>?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kubbcoach", category: "locationCapture")

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Best-effort one-shot capture. Returns nil when permission is denied,
    /// location lookup fails, or the 5-second timeout fires. Never throws.
    func fetchCurrentPlace(timeout: TimeInterval = 5) async -> CapturedPlace? {
        let status = await ensurePermission()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            logger.info("Location capture skipped — auth status \(status.rawValue)")
            return nil
        }

        guard let location = await requestSingleLocation(timeout: timeout) else {
            return nil
        }

        let coordinate = location.coordinate
        let displayName = await reverseGeocode(location) ?? formatCoordinateFallback(coordinate)
        return CapturedPlace(coordinate: coordinate, displayName: displayName)
    }

    // MARK: - Permission

    private func ensurePermission() async -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        if current != .notDetermined { return current }

        let status = await withCheckedContinuation { continuation in
            pendingAuth = continuation
            manager.requestWhenInUseAuthorization()

            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
                guard let self else { return }
                if let pending = self.pendingAuth {
                    self.pendingAuth = nil
                    pending.resume(returning: self.manager.authorizationStatus)
                }
            }
        }
        return status
    }

    // MARK: - Single-shot location

    private func requestSingleLocation(timeout: TimeInterval) async -> CLLocation? {
        await withCheckedContinuation { continuation in
            pendingLocation = continuation
            manager.requestLocation()

            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard let self else { return }
                if let pending = self.pendingLocation {
                    self.pendingLocation = nil
                    self.logger.info("Location capture timed out after \(timeout, format: .fixed(precision: 1))s")
                    pending.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Reverse geocoding

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }

            let locality = placemark.locality ?? placemark.subLocality ?? placemark.subAdministrativeArea
            let region = placemark.isoCountryCode ?? placemark.administrativeArea ?? placemark.country

            switch (locality, region) {
            case let (loc?, reg?): return "\(loc), \(reg)"
            case let (loc?, nil): return loc
            case let (nil, reg?): return reg
            case (nil, nil): return nil
            }
        } catch {
            logger.warning("Reverse geocoding failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func formatCoordinateFallback(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.2f, %.2f", coordinate.latitude, coordinate.longitude)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationCaptureService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            // Skip the initial-delegate-assignment fire (status is still
            // .notDetermined) and any other pre-decision callbacks. We only
            // want to resume when the user has actually chosen.
            guard status != .notDetermined else { return }
            if let continuation = pendingAuth {
                pendingAuth = nil
                continuation.resume(returning: status)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        Task { @MainActor in
            if let continuation = pendingLocation {
                pendingLocation = nil
                continuation.resume(returning: latest)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            logger.warning("CLLocationManager failed: \(error.localizedDescription)")
            if let continuation = pendingLocation {
                pendingLocation = nil
                continuation.resume(returning: nil)
            }
        }
    }
}

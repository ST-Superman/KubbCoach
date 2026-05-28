//
//  SessionConditionsCapture.swift
//  Kubb Coach
//
//  Shared, best-effort "capture location + weather at session start" flow
//  used by TrainingSession, PressureCookerSession, and GameSession. The
//  capture is fire-and-forget: writes land on the session object even if
//  the user has already moved on to the first round/turn.
//

import Foundation
import SwiftData

/// Any session-like model that records the location + weather snapshot
/// captured at session start.
protocol HasWeatherFields: AnyObject {
    var locationName: String? { get set }
    var latitude: Double? { get set }
    var longitude: Double? { get set }
    var windSpeedMph: Double? { get set }
    var windDirection: String? { get set }
    var weatherCondition: String? { get set }
    var temperatureF: Double? { get set }
    var precipitationIntensity: Double? { get set }
    var precipitation24hMm: Double? { get set }
}

enum SessionConditionsCapture {

    /// Fires a non-blocking capture of location + weather and writes the
    /// snapshot back onto `session`. Honors the `captureSessionConditions`
    /// preference (defaults true) and silently no-ops when permission is
    /// denied or any network/lookup step fails.
    static func captureIfEnabled<S: HasWeatherFields>(for session: S, in context: ModelContext) {
        let enabled = UserDefaults.standard.object(forKey: "captureSessionConditions") as? Bool ?? true
        guard enabled else { return }

        Task { @MainActor in
            guard let place = await LocationCaptureService.shared.fetchCurrentPlace() else { return }
            session.locationName = place.displayName
            session.latitude = place.coordinate.latitude
            session.longitude = place.coordinate.longitude

            if let weather = await WeatherCaptureService.shared.fetchSnapshot(at: place.coordinate) {
                session.windSpeedMph = weather.windSpeedMph
                session.windDirection = weather.windDirection
                session.weatherCondition = weather.condition
                session.temperatureF = weather.temperatureF
                session.precipitationIntensity = weather.precipitationIntensityMmPerHour
                session.precipitation24hMm = weather.precipitation24hMm
            }

            do {
                try context.save()
            } catch {
                AppLogger.training.warning("Failed to persist captured conditions: \(error.localizedDescription)")
            }
        }
    }
}

extension TrainingSession: HasWeatherFields {}
extension PressureCookerSession: HasWeatherFields {}
extension GameSession: HasWeatherFields {}

//
//  WeatherCaptureService.swift
//  Kubb Coach
//
//  Wraps WeatherKit to fetch a one-shot snapshot of current conditions plus
//  the prior 24 hours of precipitation for the session Conditions display.
//

import Foundation
import CoreLocation
import WeatherKit
import OSLog

struct WeatherSnapshot {
    let windSpeedMph: Double?
    let windDirection: String?
    let condition: String
    let temperatureF: Double
    let precipitationIntensityMmPerHour: Double?
    let precipitation24hMm: Double?
}

@MainActor
final class WeatherCaptureService {
    static let shared = WeatherCaptureService()

    private let service = WeatherService.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kubbcoach", category: "weatherCapture")

    private init() {}

    /// Best-effort snapshot. Returns nil on any network/entitlement failure.
    func fetchSnapshot(at coordinate: CLLocationCoordinate2D) async -> WeatherSnapshot? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let weather = try await service.weather(for: location)

            let current = weather.currentWeather
            let windMph = current.wind.speed.converted(to: .milesPerHour).value
            let direction = current.wind.compassDirection.abbreviation
            let tempF = current.temperature.converted(to: .fahrenheit).value
            // WeatherKit's precipitationIntensity uses UnitSpeed (m/s under the hood).
            // Convert to mm/h: (m/s) × 1000 mm/m × 3600 s/h.
            let metersPerSecond = current.precipitationIntensity.converted(to: .metersPerSecond).value
            let precipNow = metersPerSecond * 1000 * 3600

            let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
            let recentHourly = weather.hourlyForecast.forecast.filter { $0.date >= twentyFourHoursAgo && $0.date <= Date() }
            let precip24h = recentHourly.reduce(0.0) { acc, hour in
                acc + hour.precipitationAmount.converted(to: .millimeters).value
            }

            return WeatherSnapshot(
                windSpeedMph: windMph,
                windDirection: direction,
                condition: current.condition.description,
                temperatureF: tempF,
                precipitationIntensityMmPerHour: precipNow,
                precipitation24hMm: recentHourly.isEmpty ? nil : precip24h
            )
        } catch {
            logger.warning("Weather fetch failed: \(error.localizedDescription)")
            return nil
        }
    }
}

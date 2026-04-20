import Foundation

struct OpenMeteoAPIClient {
    private struct Response: Decodable {
        struct Hourly: Decodable {
            let time: [String]
            let temperature2M: [Double]
            let precipitationProbability: [Int?]?
            let weatherCode: [Int]
            let windSpeed10M: [Double?]?

            enum CodingKeys: String, CodingKey {
                case time
                case temperature2M = "temperature_2m"
                case precipitationProbability = "precipitation_probability"
                case weatherCode = "weather_code"
                case windSpeed10M = "wind_speed_10m"
            }
        }

        let timezone: String
        let hourly: Hourly
    }

    private let httpClient: any HTTPClient
    private let endpoint = URL(string: "https://api.open-meteo.com/v1/forecast")!

    init(httpClient: any HTTPClient) {
        self.httpClient = httpClient
    }

    func fetchForecast(latitude: Double, longitude: Double, shootWindow: DateInterval) async throws -> LocationWeatherSummary? {
        let response: Response = try await httpClient.get(
            url: endpoint,
            headers: [:],
            queryItems: [
                URLQueryItem(name: "latitude", value: String(latitude)),
                URLQueryItem(name: "longitude", value: String(longitude)),
                URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability,weather_code,wind_speed_10m"),
                URLQueryItem(name: "forecast_days", value: "2"),
                URLQueryItem(name: "timezone", value: "auto")
            ],
            timeout: 20
        )

        let timezone = TimeZone(identifier: response.timezone) ?? .autoupdatingCurrent
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        let snapshots = response.hourly.time.enumerated().compactMap { index, rawTimestamp -> LocationWeatherSnapshot? in
            guard let time = formatter.date(from: rawTimestamp), index < response.hourly.temperature2M.count, index < response.hourly.weatherCode.count else {
                return nil
            }

            let precipitationProbability = response.hourly.precipitationProbability?[safe: index] ?? nil
            let windSpeed = response.hourly.windSpeed10M?[safe: index] ?? nil

            return LocationWeatherSnapshot(
                time: time,
                temperatureCelsius: response.hourly.temperature2M[index],
                precipitationProbability: precipitationProbability,
                windSpeedKilometersPerHour: windSpeed,
                conditionSummary: Self.weatherDescription(for: response.hourly.weatherCode[index])
            )
        }

        let selectedSnapshots = snapshots.filter {
            $0.time >= shootWindow.start.addingTimeInterval(-3600) && $0.time <= shootWindow.end.addingTimeInterval(3600)
        }

        let finalSnapshots = Array((selectedSnapshots.isEmpty ? snapshots.prefix(6) : selectedSnapshots.prefix(6)))
        guard let firstSnapshot = finalSnapshots.first else {
            return nil
        }

        let rainText: String
        if let precipitationProbability = firstSnapshot.precipitationProbability {
            rainText = "\(precipitationProbability)% rain"
        } else {
            rainText = "rain chance unavailable"
        }

        let windText: String
        if let windSpeed = firstSnapshot.windSpeedKilometersPerHour {
            windText = "\(Int(windSpeed.rounded())) km/h wind"
        } else {
            windText = "wind unavailable"
        }

        let summary = "\(Int(firstSnapshot.temperatureCelsius.rounded()))°C, \(firstSnapshot.conditionSummary.lowercased()), \(rainText), \(windText)."

        return LocationWeatherSummary(
            summary: summary,
            timezoneIdentifier: response.timezone,
            snapshots: finalSnapshots
        )
    }

    private static func weatherDescription(for code: Int) -> String {
        switch code {
        case 0:
            return "Clear sky"
        case 1, 2:
            return "Partly cloudy"
        case 3:
            return "Overcast"
        case 45, 48:
            return "Fog"
        case 51, 53, 55, 56, 57:
            return "Drizzle"
        case 61, 63, 65, 66, 67:
            return "Rain"
        case 71, 73, 75, 77:
            return "Snow"
        case 80, 81, 82:
            return "Rain showers"
        case 85, 86:
            return "Snow showers"
        case 95, 96, 99:
            return "Thunderstorm"
        default:
            return "Mixed conditions"
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }

        return self[index]
    }
}
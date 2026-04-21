import Foundation

enum LocationContextProviderState: String, Codable {
    case success
    case skipped
    case failed
}

struct LocationContextProviderStatus: Codable {
    let state: LocationContextProviderState
    let detail: String

    static func success(_ detail: String) -> LocationContextProviderStatus {
        LocationContextProviderStatus(state: .success, detail: detail)
    }

    static func skipped(_ detail: String) -> LocationContextProviderStatus {
        LocationContextProviderStatus(state: .skipped, detail: detail)
    }

    static func failed(_ detail: String) -> LocationContextProviderStatus {
        LocationContextProviderStatus(state: .failed, detail: detail)
    }
}

struct LocationContextBundle: Codable {
    struct LocationSummary: Codable {
        let name: String
        let latitude: Double
        let longitude: Double
    }

    struct ShootWindowSummary: Codable {
        let start: Date
        let end: Date
        let label: String
    }

    struct ProviderStatuses: Codable {
        let overpass: LocationContextProviderStatus
        let wikipedia: LocationContextProviderStatus
        let flickr: LocationContextProviderStatus
        let openMeteo: LocationContextProviderStatus
        let sunMoon: LocationContextProviderStatus
    }

    let generatedAt: Date
    let location: LocationSummary
    let shootWindow: ShootWindowSummary
    let highlights: [String]
    let providerStatuses: ProviderStatuses
    let pointsOfInterest: [LocationPointOfInterest]
    let wikipedia: LocationWikipediaSummary?
    let referenceImages: [LocationReferenceImage]
    let weather: LocationWeatherSummary?
    let sunMoon: LocationSunMoonSummary

    func formattedJSONString() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        return String(decoding: data, as: UTF8.self)
    }

    static func decode(from jsonString: String) -> LocationContextBundle? {
        let trimmedString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedString.isEmpty, let data = trimmedString.data(using: .utf8) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(LocationContextBundle.self, from: data)
    }
}

struct LocationPointOfInterest: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let distanceMeters: Double?
    let latitude: Double
    let longitude: Double
    let sourceTags: [String: String]
}

struct LocationWikipediaSummary: Codable {
    let title: String
    let summary: String
    let detail: String?
    let pageURLString: String?
    let distanceMeters: Double?
}

struct LocationReferenceImage: Codable, Identifiable {
    let id: String
    let title: String
    let ownerName: String
    let pageURLString: String
    let imageURLString: String?
    let capturedAt: String?
    let tags: [String]
}

struct LocationWeatherSummary: Codable {
    let summary: String
    let timezoneIdentifier: String
    let snapshots: [LocationWeatherSnapshot]
}

struct LocationWeatherSnapshot: Codable, Identifiable {
    let time: Date
    let temperatureCelsius: Double
    let precipitationProbability: Int?
    let windSpeedKilometersPerHour: Double?
    let conditionSummary: String

    var id: Date { time }
}

struct LocationSunMoonSummary: Codable {
    let sunrise: Date?
    let sunset: Date?
    let civilDawn: Date?
    let civilDusk: Date?
    let blueHourMorningStart: Date?
    let blueHourMorningEnd: Date?
    let goldenHourMorningStart: Date?
    let goldenHourMorningEnd: Date?
    let goldenHourEveningStart: Date?
    let goldenHourEveningEnd: Date?
    let blueHourEveningStart: Date?
    let blueHourEveningEnd: Date?
    let moonPhaseName: String
    let moonIlluminationPercent: Double
}
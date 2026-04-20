import Foundation

struct OverpassAPIClient {
    private struct Response: Decodable {
        struct Element: Decodable {
            struct Center: Decodable {
                let lat: Double
                let lon: Double
            }

            let type: String
            let id: Int
            let lat: Double?
            let lon: Double?
            let center: Center?
            let tags: [String: String]?
        }

        let elements: [Element]
    }

    private let httpClient: any HTTPClient
    private let endpoint = URL(string: "https://overpass-api.de/api/interpreter")!

    init(httpClient: any HTTPClient) {
        self.httpClient = httpClient
    }

    func fetchPointsOfInterest(latitude: Double, longitude: Double, radiusMeters: Int = 1600) async throws -> [LocationPointOfInterest] {
        let query = """
        [out:json][timeout:25];
        (
          node(around:\(radiusMeters),\(latitude),\(longitude))[\"tourism\"~\"viewpoint|attraction|museum|gallery|artwork\"];
          way(around:\(radiusMeters),\(latitude),\(longitude))[\"tourism\"~\"viewpoint|attraction|museum|gallery|artwork\"];
          relation(around:\(radiusMeters),\(latitude),\(longitude))[\"tourism\"~\"viewpoint|attraction|museum|gallery|artwork\"];
          node(around:\(radiusMeters),\(latitude),\(longitude))[\"historic\"];
          way(around:\(radiusMeters),\(latitude),\(longitude))[\"historic\"];
          relation(around:\(radiusMeters),\(latitude),\(longitude))[\"historic\"];
          node(around:\(radiusMeters),\(latitude),\(longitude))[\"natural\"~\"peak|beach|water|wood\"];
          way(around:\(radiusMeters),\(latitude),\(longitude))[\"highway\"~\"path|footway\"][\"name\"];
        );
        out center;
        """

        let response: Response = try await httpClient.get(
            url: endpoint,
            headers: [:],
            queryItems: [URLQueryItem(name: "data", value: query)],
            timeout: 30
        )

        return response.elements
            .compactMap { element in
                guard let tags = element.tags else {
                    return nil
                }

                let nameCandidates = [tags["name"], tags["name:en"], tags["official_name"]]
                guard let name = nameCandidates.compactMap(Self.normalizedValue).first else {
                    return nil
                }

                let resolvedLatitude = element.lat ?? element.center?.lat
                let resolvedLongitude = element.lon ?? element.center?.lon
                guard let resolvedLatitude, let resolvedLongitude else {
                    return nil
                }

                let distanceMeters = Self.distance(
                    latitudeA: latitude,
                    longitudeA: longitude,
                    latitudeB: resolvedLatitude,
                    longitudeB: resolvedLongitude
                )

                let keptTags = tags.filter { key, _ in
                    ["tourism", "historic", "natural", "highway", "amenity", "wikipedia", "wikidata"].contains(key)
                }

                return LocationPointOfInterest(
                    id: "\(element.type)-\(element.id)",
                    name: name,
                    category: Self.categoryLabel(for: tags),
                    distanceMeters: distanceMeters,
                    latitude: resolvedLatitude,
                    longitude: resolvedLongitude,
                    sourceTags: keptTags
                )
            }
            .sorted { ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude) }
            .prefix(12)
            .map { $0 }
    }

    private static func categoryLabel(for tags: [String: String]) -> String {
        if let tourism = normalizedValue(tags["tourism"]) {
            return tourism.replacingOccurrences(of: "_", with: " ").capitalized
        }

        if let historic = normalizedValue(tags["historic"]) {
            return historic.replacingOccurrences(of: "_", with: " ").capitalized
        }

        if let natural = normalizedValue(tags["natural"]) {
            return natural.replacingOccurrences(of: "_", with: " ").capitalized
        }

        if let highway = normalizedValue(tags["highway"]) {
            return highway.replacingOccurrences(of: "_", with: " ").capitalized
        }

        return "Point of interest"
    }

    private static func normalizedValue(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private static func distance(
        latitudeA: Double,
        longitudeA: Double,
        latitudeB: Double,
        longitudeB: Double
    ) -> Double {
        let earthRadiusMeters = 6_371_000.0
        let latitudeDelta = (latitudeB - latitudeA) * .pi / 180
        let longitudeDelta = (longitudeB - longitudeA) * .pi / 180
        let startLatitude = latitudeA * .pi / 180
        let endLatitude = latitudeB * .pi / 180

        let haversine = pow(sin(latitudeDelta / 2), 2)
            + cos(startLatitude) * cos(endLatitude) * pow(sin(longitudeDelta / 2), 2)

        let arc = 2 * atan2(sqrt(haversine), sqrt(1 - haversine))
        return earthRadiusMeters * arc
    }
}
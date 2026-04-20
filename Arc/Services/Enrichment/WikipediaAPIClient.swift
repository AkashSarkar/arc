import Foundation

struct WikipediaAPIClient {
    private struct GeoSearchResponse: Decodable {
        struct Query: Decodable {
            struct Result: Decodable {
                let pageid: Int
                let title: String
                let dist: Double?
            }

            let geosearch: [Result]
        }

        let query: Query?
    }

    private struct SummaryResponse: Decodable {
        struct ContentURLs: Decodable {
            struct Desktop: Decodable {
                let page: String?
            }

            let desktop: Desktop?

            enum CodingKeys: String, CodingKey {
                case desktop
            }
        }

        let title: String
        let extract: String?
        let description: String?
        let contentURLs: ContentURLs?

        enum CodingKeys: String, CodingKey {
            case title
            case extract
            case description
            case contentURLs = "content_urls"
        }
    }

    private let httpClient: any HTTPClient
    private let apiURL = URL(string: "https://en.wikipedia.org/w/api.php")!
    private let userAgent = "Arc/1.0 (Location enrichment)"

    init(httpClient: any HTTPClient) {
        self.httpClient = httpClient
    }

    func fetchLandmarkContext(latitude: Double, longitude: Double) async throws -> LocationWikipediaSummary? {
        let geoSearchResponse: GeoSearchResponse = try await httpClient.get(
            url: apiURL,
            headers: ["User-Agent": userAgent],
            queryItems: [
                URLQueryItem(name: "action", value: "query"),
                URLQueryItem(name: "list", value: "geosearch"),
                URLQueryItem(name: "gscoord", value: "\(latitude)|\(longitude)"),
                URLQueryItem(name: "gsradius", value: "10000"),
                URLQueryItem(name: "gslimit", value: "1"),
                URLQueryItem(name: "format", value: "json")
            ],
            timeout: 20
        )

        guard let result = geoSearchResponse.query?.geosearch.first else {
            return nil
        }

        let encodedTitle = result.title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? result.title
        let summaryURL = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encodedTitle)")!
        let summaryResponse: SummaryResponse = try await httpClient.get(
            url: summaryURL,
            headers: ["User-Agent": userAgent],
            queryItems: [],
            timeout: 20
        )

        return LocationWikipediaSummary(
            title: summaryResponse.title,
            summary: summaryResponse.extract?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            detail: summaryResponse.description?.trimmingCharacters(in: .whitespacesAndNewlines),
            pageURLString: summaryResponse.contentURLs?.desktop?.page,
            distanceMeters: result.dist
        )
    }
}
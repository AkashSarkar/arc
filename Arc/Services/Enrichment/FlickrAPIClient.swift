import Foundation

enum FlickrAPIClientError: LocalizedError {
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No Flickr API key is stored in Keychain account arc.api.flickr."
        }
    }
}

struct FlickrAPIClient {
    private struct Response: Decodable {
        struct PhotosContainer: Decodable {
            struct Photo: Decodable {
                struct Description: Decodable {
                    let _content: String?
                }

                let id: String
                let owner: String
                let ownername: String?
                let title: String
                let datetaken: String?
                let tags: String?
                let urlM: String?
                let urlL: String?

                enum CodingKeys: String, CodingKey {
                    case id
                    case owner
                    case ownername
                    case title
                    case datetaken
                    case tags
                    case urlM = "url_m"
                    case urlL = "url_l"
                }
            }

            let photo: [Photo]
        }

        let photos: PhotosContainer
    }

    static let apiKeyAccount = "arc.api.flickr"

    private let httpClient: any HTTPClient
    private let apiKeyProvider: any APIKeyProviding
    private let endpoint = URL(string: "https://api.flickr.com/services/rest/")!

    init(httpClient: any HTTPClient, apiKeyProvider: any APIKeyProviding) {
        self.httpClient = httpClient
        self.apiKeyProvider = apiKeyProvider
    }

    func fetchReferenceImages(latitude: Double, longitude: Double, perPage: Int = 12) async throws -> [LocationReferenceImage] {
        guard let apiKey = try apiKeyProvider.apiKey(for: Self.apiKeyAccount), !apiKey.isEmpty else {
            throw FlickrAPIClientError.missingAPIKey
        }

        let response: Response = try await httpClient.get(
            url: endpoint,
            headers: [:],
            queryItems: [
                URLQueryItem(name: "method", value: "flickr.photos.search"),
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "lat", value: String(latitude)),
                URLQueryItem(name: "lon", value: String(longitude)),
                URLQueryItem(name: "radius", value: "3"),
                URLQueryItem(name: "radius_units", value: "km"),
                URLQueryItem(name: "sort", value: "interestingness-desc"),
                URLQueryItem(name: "content_type", value: "1"),
                URLQueryItem(name: "media", value: "photos"),
                URLQueryItem(name: "has_geo", value: "1"),
                URLQueryItem(name: "extras", value: "date_taken,owner_name,tags,url_m,url_l"),
                URLQueryItem(name: "per_page", value: String(perPage)),
                URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "nojsoncallback", value: "1")
            ],
            timeout: 30
        )

        return response.photos.photo.compactMap { photo in
            let imageURL = photo.urlL ?? photo.urlM
            let title = photo.title.trimmingCharacters(in: .whitespacesAndNewlines)

            return LocationReferenceImage(
                id: photo.id,
                title: title.isEmpty ? "Untitled Flickr image" : title,
                ownerName: photo.ownername?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown photographer",
                pageURLString: "https://www.flickr.com/photos/\(photo.owner)/\(photo.id)",
                imageURLString: imageURL,
                capturedAt: photo.datetaken,
                tags: photo.tags?
                    .split(separator: " ")
                    .map(String.init)
                    .filter { !$0.isEmpty } ?? []
            )
        }
    }
}
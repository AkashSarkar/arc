import Foundation

struct AppContainer {
    let aiService: any AIServicing
    let locationEditorServices: LocationEditorServiceFactory

    static let live: AppContainer = {
        let configuration = AIConfiguration.fromBundle()
        let keychainStore = KeychainStore()
        let httpClient = URLSessionHTTPClient()
        let rateLimiter = FixedWindowRateLimiter(
            maxRequests: configuration.requestsPerMinute,
            window: 60
        )

        let service = OpenAICompatibleAIService(
            configuration: configuration,
            httpClient: httpClient,
            keyProvider: keychainStore,
            rateLimiter: rateLimiter
        )

        return AppContainer(
            aiService: service,
            locationEditorServices: .live
        )
    }()
}

import Foundation

struct AppContainer {
    let defaultAIConfiguration: AIConfiguration
    let makeAIService: (LLMProfile?) -> any AIServicing
    let apiKeyStore: any APIKeyProviding
    let locationEnricher: any LocationEnriching
    let referenceImageCache: any ReferenceImageCaching
    let locationEditorServices: LocationEditorServiceFactory

    static let live: AppContainer = {
        let configuration = AIConfiguration.fromBundle()
        let keychainStore = KeychainStore()
        let httpClient = URLSessionHTTPClient()
        let locationEnricher = LocationEnricher(
            overpassClient: OverpassAPIClient(httpClient: httpClient),
            wikipediaClient: WikipediaAPIClient(httpClient: httpClient),
            flickrClient: FlickrAPIClient(httpClient: httpClient, apiKeyProvider: keychainStore),
            openMeteoClient: OpenMeteoAPIClient(httpClient: httpClient),
            sunMoonCalculator: SunMoonCalculator()
        )

        return AppContainer(
            defaultAIConfiguration: configuration,
            makeAIService: { profile in
                let resolvedConfiguration = AIConfiguration.resolved(profile: profile, defaults: configuration)
                return OpenAICompatibleAIService(
                    configuration: resolvedConfiguration,
                    httpClient: httpClient,
                    keyProvider: keychainStore,
                    rateLimiter: FixedWindowRateLimiter(
                        maxRequests: resolvedConfiguration.requestsPerMinute,
                        window: 60
                    )
                )
            },
            apiKeyStore: keychainStore,
            locationEnricher: locationEnricher,
            referenceImageCache: DiskReferenceImageCache(),
            locationEditorServices: .live
        )
    }()
}

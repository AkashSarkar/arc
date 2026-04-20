import Foundation

struct AppContainer {
    let defaultAIConfiguration: AIConfiguration
    let makeAIService: (LLMProfile?) -> any AIServicing
    let apiKeyStore: any APIKeyProviding
    let locationEditorServices: LocationEditorServiceFactory

    static let live: AppContainer = {
        let configuration = AIConfiguration.fromBundle()
        let keychainStore = KeychainStore()
        let httpClient = URLSessionHTTPClient()

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
            locationEditorServices: .live
        )
    }()
}

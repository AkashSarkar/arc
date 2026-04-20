import Foundation

struct OpenAICompatibleAIService: AIServicing {
    private let configuration: AIConfiguration
    private let httpClient: any HTTPClient
    private let keyProvider: any APIKeyProviding
    private let rateLimiter: FixedWindowRateLimiter

    init(
        configuration: AIConfiguration,
        httpClient: any HTTPClient,
        keyProvider: any APIKeyProviding,
        rateLimiter: FixedWindowRateLimiter
    ) {
        self.configuration = configuration
        self.httpClient = httpClient
        self.keyProvider = keyProvider
        self.rateLimiter = rateLimiter
    }

    func generateShotPlan(for prompt: String) async throws -> String {
        try await rateLimiter.acquire()

        guard let apiKey = try keyProvider.apiKey(for: configuration.apiKeyAccount), !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }

        let endpoint = configuration.baseURL.appending(path: "chat/completions")
        let request = ChatCompletionsRequest(
            model: configuration.modelName,
            messages: [
                .init(role: "system", content: "You are a precise photography planner. Keep responses concise and practical."),
                .init(role: "user", content: prompt)
            ],
            maxTokens: configuration.maxTokens,
            temperature: configuration.temperature
        )

        let response: ChatCompletionsResponse = try await httpClient.post(
            url: endpoint,
            headers: ["Authorization": "Bearer \(apiKey)"],
            body: request,
            timeout: configuration.timeoutSeconds
        )

        guard let content = response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty
        else {
            throw AIServiceError.emptyResponse
        }

        return content
    }
}

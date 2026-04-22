import Foundation

struct OpenAICompatibleAIService: AIServicing {
    private static let defaultSystemPrompt = "You are a precise photography planner. Return only the final answer in message content. Do not include reasoning, scratchpad, or analysis. Keep responses concise and practical. /no_think"
    private static let retryTokenCap = 8000

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

        let headers = try requestHeaders()
        let initialRequest = chatCompletionsRequest(
            for: prompt,
            maxTokens: configuration.maxTokens,
            forceDirectAnswer: false
        )
        let initialResponse = try await sendChatCompletionsRequest(initialRequest, headers: headers)

        if let content = finalContent(from: initialResponse) {
            return content
        }

        if shouldRetryForReasoningOnly(initialResponse, attemptedMaxTokens: initialRequest.maxTokens) {
            let retryRequest = chatCompletionsRequest(
                for: prompt,
                maxTokens: retryMaxTokens(for: initialRequest.maxTokens),
                forceDirectAnswer: true
            )
            let retryResponse = try await sendChatCompletionsRequest(retryRequest, headers: headers)

            if let content = finalContent(from: retryResponse) {
                return content
            }

            if isReasoningOnlyResponse(retryResponse) {
                throw AIServiceError.reasoningOnlyResponse
            }
        }

        if isReasoningOnlyResponse(initialResponse) {
            throw AIServiceError.reasoningOnlyResponse
        }

        throw AIServiceError.emptyResponse
    }

    private func requestHeaders() throws -> [String: String] {
        var headers: [String: String] = [:]

        if configuration.requiresAPIKey {
            guard let account = configuration.apiKeyAccount,
                  let apiKey = try keyProvider.apiKey(for: account),
                  !apiKey.isEmpty
            else {
                throw AIServiceError.missingAPIKey
            }

            headers["Authorization"] = "Bearer \(apiKey)"
        } else if let account = configuration.apiKeyAccount,
                  let apiKey = try keyProvider.apiKey(for: account),
                  !apiKey.isEmpty {
            headers["Authorization"] = "Bearer \(apiKey)"
        }

        return headers
    }

    private func chatCompletionsRequest(
        for prompt: String,
        maxTokens: Int,
        forceDirectAnswer: Bool
    ) -> ChatCompletionsRequest {
        let systemPrompt: String
        if forceDirectAnswer {
            systemPrompt = Self.defaultSystemPrompt + " Respond immediately with the final answer."
        } else {
            systemPrompt = Self.defaultSystemPrompt
        }

        return ChatCompletionsRequest(
            model: configuration.modelName,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: prompt)
            ],
            maxTokens: maxTokens,
            temperature: configuration.temperature,
            responseFormat: nil
        )
    }

    private func sendChatCompletionsRequest(
        _ request: ChatCompletionsRequest,
        headers: [String: String]
    ) async throws -> ChatCompletionsResponse {
        try await httpClient.post(
            url: configuration.chatCompletionsURL,
            headers: headers,
            body: request,
            timeout: configuration.timeoutSeconds
        )
    }

    private func finalContent(from response: ChatCompletionsResponse) -> String? {
        guard let content = response.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty
        else {
            return nil
        }

        return content
    }

    private func shouldRetryForReasoningOnly(
        _ response: ChatCompletionsResponse,
        attemptedMaxTokens: Int
    ) -> Bool {
        guard isReasoningOnlyResponse(response) else {
            return false
        }

        guard let finishReason = response.choices.first?.finishReason?.lowercased() else {
            return false
        }

        return finishReason == "length" && attemptedMaxTokens < Self.retryTokenCap
    }

    private func isReasoningOnlyResponse(_ response: ChatCompletionsResponse) -> Bool {
        guard let choice = response.choices.first else {
            return false
        }

        let trimmedContent = choice.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedReasoning = choice.message.reasoningContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedContent.isEmpty && !trimmedReasoning.isEmpty
    }

    private func retryMaxTokens(for _: Int) -> Int {
        Self.retryTokenCap
    }
}

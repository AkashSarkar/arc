import Foundation

struct AIConfiguration {
    let baseURL: URL
    let modelName: String
    let timeoutSeconds: TimeInterval
    let maxTokens: Int
    let temperature: Double
    let requestsPerMinute: Int
    let apiKeyAccount: String?
    let requiresAPIKey: Bool
    let useStructuredOutput: Bool

    var chatCompletionsURL: URL {
        let normalizedBaseURL = Self.normalizedOpenAICompatibleBaseURL(baseURL)
        let trimmedPath = normalizedBaseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if trimmedPath.hasSuffix("chat/completions") {
            return normalizedBaseURL
        }

        return normalizedBaseURL.appending(path: "chat/completions")
    }

    static func fromBundle(bundle: Bundle = .main) -> AIConfiguration {
        let baseURLString = bundle.object(forInfoDictionaryKey: "AI_BASE_URL") as? String ?? "https://api.openai.com/v1"
        let modelName = bundle.object(forInfoDictionaryKey: "AI_MODEL_NAME") as? String ?? "gpt-4o-mini"
        let timeoutSeconds = bundle.object(forInfoDictionaryKey: "AI_TIMEOUT_SECONDS") as? TimeInterval ?? 30
        let maxTokens = bundle.object(forInfoDictionaryKey: "AI_MAX_TOKENS") as? Int ?? 800
        let temperature = bundle.object(forInfoDictionaryKey: "AI_TEMPERATURE") as? Double ?? 0.2
        let requestsPerMinute = bundle.object(forInfoDictionaryKey: "AI_REQUESTS_PER_MINUTE") as? Int ?? 20
        let rawAPIKeyAccount = bundle.object(forInfoDictionaryKey: "AI_API_KEY_ACCOUNT") as? String ?? "arc.ai.default"
        let apiKeyAccount = normalizedKeyAccount(rawAPIKeyAccount)
        let useStructuredOutput = bundle.object(forInfoDictionaryKey: "AI_USE_STRUCTURED_OUTPUT") as? Bool ?? false
        let baseURL = normalizedOpenAICompatibleBaseURL(
            URL(string: baseURLString) ?? URL(string: "https://api.openai.com/v1")!
        )

        return AIConfiguration(
            baseURL: baseURL,
            modelName: modelName,
            timeoutSeconds: timeoutSeconds,
            maxTokens: maxTokens,
            temperature: temperature,
            requestsPerMinute: max(1, requestsPerMinute),
            apiKeyAccount: apiKeyAccount,
            requiresAPIKey: apiKeyAccount != nil,
            useStructuredOutput: useStructuredOutput
        )
    }

    static func resolved(profile: LLMProfile?, defaults: AIConfiguration) -> AIConfiguration {
        guard let profile else {
            return defaults
        }

        return AIConfiguration(
            baseURL: normalizedOpenAICompatibleBaseURL(profile.baseURL),
            modelName: profile.modelName,
            timeoutSeconds: profile.timeoutSeconds,
            maxTokens: defaults.maxTokens,
            temperature: defaults.temperature,
            requestsPerMinute: defaults.requestsPerMinute,
            apiKeyAccount: normalizedKeyAccount(profile.apiKeyAccount),
            requiresAPIKey: profile.requiresAPIKey,
            useStructuredOutput: profile.useStructuredOutput
        )
    }

    static func normalizedOpenAICompatibleBaseURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmedPath.isEmpty {
            components.path = "/v1"
            return components.url ?? url
        }

        return components.url ?? url
    }

    private static func normalizedKeyAccount(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

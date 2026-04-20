import Foundation

struct AIConfiguration {
    let baseURL: URL
    let modelName: String
    let timeoutSeconds: TimeInterval
    let maxTokens: Int
    let temperature: Double
    let requestsPerMinute: Int
    let apiKeyAccount: String

    static func fromBundle(bundle: Bundle = .main) -> AIConfiguration {
        let baseURLString = bundle.object(forInfoDictionaryKey: "AI_BASE_URL") as? String ?? "https://api.openai.com/v1"
        let modelName = bundle.object(forInfoDictionaryKey: "AI_MODEL_NAME") as? String ?? "gpt-4o-mini"
        let timeoutSeconds = bundle.object(forInfoDictionaryKey: "AI_TIMEOUT_SECONDS") as? TimeInterval ?? 30
        let maxTokens = bundle.object(forInfoDictionaryKey: "AI_MAX_TOKENS") as? Int ?? 800
        let temperature = bundle.object(forInfoDictionaryKey: "AI_TEMPERATURE") as? Double ?? 0.2
        let requestsPerMinute = bundle.object(forInfoDictionaryKey: "AI_REQUESTS_PER_MINUTE") as? Int ?? 20
        let apiKeyAccount = bundle.object(forInfoDictionaryKey: "AI_API_KEY_ACCOUNT") as? String ?? "arc.ai.default"

        return AIConfiguration(
            baseURL: URL(string: baseURLString) ?? URL(string: "https://api.openai.com/v1")!,
            modelName: modelName,
            timeoutSeconds: timeoutSeconds,
            maxTokens: maxTokens,
            temperature: temperature,
            requestsPerMinute: max(1, requestsPerMinute),
            apiKeyAccount: apiKeyAccount
        )
    }
}

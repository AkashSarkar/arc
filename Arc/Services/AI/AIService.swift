import Foundation

protocol AIServicing {
    func generateShotPlan(for prompt: String) async throws -> String
}

enum AIServiceError: LocalizedError {
    case missingAPIKey
    case emptyResponse
    case reasoningOnlyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key found in Keychain."
        case .emptyResponse:
            return "AI response was empty."
        case .reasoningOnlyResponse:
            return "The selected model returned reasoning but no final answer. Use a non-thinking chat model or a higher token budget."
        }
    }
}

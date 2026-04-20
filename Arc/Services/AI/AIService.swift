import Foundation

protocol AIServicing {
    func generateShotPlan(for prompt: String) async throws -> String
}

enum AIServiceError: LocalizedError {
    case missingAPIKey
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key found in Keychain."
        case .emptyResponse:
            return "AI response was empty."
        }
    }
}

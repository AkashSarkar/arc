import Foundation

enum NetworkError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case decodingFailure

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Received an invalid response from the server."
        case let .serverError(statusCode, message):
            if let message, !message.isEmpty {
                return "Server returned \(statusCode): \(message)"
            }
            return "Server returned status code \(statusCode)."
        case .decodingFailure:
            return "Failed to decode the server response."
        }
    }
}

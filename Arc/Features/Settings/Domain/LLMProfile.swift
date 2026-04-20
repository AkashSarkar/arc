import Foundation
import SwiftData

@Model
final class LLMProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var baseURLString: String
    var modelName: String
    var apiKeyAccount: String?
    var requiresAPIKey: Bool
    var useStructuredOutput: Bool
    var timeoutSeconds: TimeInterval
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        baseURLString: String,
        modelName: String,
        apiKeyAccount: String? = nil,
        requiresAPIKey: Bool,
        useStructuredOutput: Bool,
        timeoutSeconds: TimeInterval,
        isActive: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.baseURLString = baseURLString
        self.modelName = modelName
        self.apiKeyAccount = apiKeyAccount
        self.requiresAPIKey = requiresAPIKey
        self.useStructuredOutput = useStructuredOutput
        self.timeoutSeconds = timeoutSeconds
        self.isActive = isActive
        self.createdAt = createdAt
    }

    var baseURL: URL {
        URL(string: baseURLString) ?? URL(string: "https://api.openai.com/v1")!
    }

    static func seededDefault(from configuration: AIConfiguration) -> LLMProfile {
        LLMProfile(
            name: "Default",
            baseURLString: configuration.baseURL.absoluteString,
            modelName: configuration.modelName,
            apiKeyAccount: configuration.apiKeyAccount,
            requiresAPIKey: configuration.requiresAPIKey,
            useStructuredOutput: false,
            timeoutSeconds: configuration.timeoutSeconds,
            isActive: true
        )
    }

    static func keychainAccount(for profileID: UUID) -> String {
        "arc.llm-profile.\(profileID.uuidString.lowercased())"
    }
}
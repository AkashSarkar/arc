import SwiftData
import SwiftUI

struct HomeView: View {
    let makeAIService: (LLMProfile?) -> any AIServicing
    let apiKeyStore: any APIKeyProviding
    let defaultAIConfiguration: AIConfiguration
    let locationEditorServices: LocationEditorServiceFactory

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LLMProfile.createdAt, order: .forward) private var llmProfiles: [LLMProfile]

    private var activeProfile: LLMProfile? {
        llmProfiles.first(where: \.isActive)
    }

    private var aiService: any AIServicing {
        makeAIService(activeProfile)
    }

    var body: some View {
        NavigationStack {
            LocationListView(
                aiService: aiService,
                apiKeyStore: apiKeyStore,
                defaultAIConfiguration: defaultAIConfiguration,
                locationEditorServices: locationEditorServices
            )
        }
        .task(id: llmProfiles.count) {
            seedDefaultProfileIfNeeded()
        }
    }

    private func seedDefaultProfileIfNeeded() {
        if llmProfiles.isEmpty {
            modelContext.insert(LLMProfile.seededDefault(from: defaultAIConfiguration))
            return
        }

        guard activeProfile == nil, let firstProfile = llmProfiles.first else {
            return
        }

        firstProfile.isActive = true
    }
}

#Preview {
    HomeView(
        makeAIService: { _ in PreviewAIService() },
        apiKeyStore: PreviewAPIKeyStore(),
        defaultAIConfiguration: AIConfiguration.fromBundle(),
        locationEditorServices: .live
    )
    .modelContainer(for: [ShootLocation.self, ShootPlan.self, ShootPlanItem.self, LLMProfile.self], inMemory: true)
}

private struct PreviewAIService: AIServicing {
    func generateShotPlan(for prompt: String) async throws -> String {
        "Preview response for: \(prompt)"
    }
}

private struct PreviewAPIKeyStore: APIKeyProviding {
    func apiKey(for account: String) throws -> String? {
        nil
    }

    func saveAPIKey(_ apiKey: String, for account: String) throws {
    }

    func deleteAPIKey(for account: String) throws {
    }
}

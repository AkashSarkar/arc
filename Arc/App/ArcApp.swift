import SwiftData
import SwiftUI

@main
struct ArcApp: App {
    private let container = AppContainer.live

    var body: some Scene {
        WindowGroup {
            HomeView(
                makeAIService: container.makeAIService,
                apiKeyStore: container.apiKeyStore,
                defaultAIConfiguration: container.defaultAIConfiguration,
                locationEnricher: container.locationEnricher,
                referenceImageCache: container.referenceImageCache,
                locationEditorServices: container.locationEditorServices
            )
            .tint(ArcPalette.tint)
        }
        .modelContainer(for: [ShootLocation.self, ShootPlan.self, ShootPlanItem.self, LLMProfile.self])
    }
}

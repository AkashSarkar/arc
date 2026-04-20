import SwiftData
import SwiftUI

@main
struct ArcApp: App {
    private let container = AppContainer.live

    var body: some Scene {
        WindowGroup {
            HomeView(
                aiService: container.aiService,
                locationEditorServices: container.locationEditorServices
            )
            .tint(ArcPalette.tint)
        }
        .modelContainer(for: [ShootLocation.self, ShootPlan.self, ShootPlanItem.self])
    }
}

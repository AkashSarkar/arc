import SwiftData
import SwiftUI

@main
struct ArcApp: App {
    private let container = AppContainer.live

    var body: some Scene {
        WindowGroup {
            HomeView(aiService: container.aiService)
        }
        .modelContainer(for: [ShootLocation.self])
    }
}

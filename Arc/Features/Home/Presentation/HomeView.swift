import SwiftUI

struct HomeView: View {
    let aiService: any AIServicing
    let locationEditorServices: LocationEditorServiceFactory

    var body: some View {
        NavigationStack {
            LocationListView(
                aiService: aiService,
                locationEditorServices: locationEditorServices
            )
        }
    }
}

#Preview {
    HomeView(
        aiService: PreviewAIService(),
        locationEditorServices: .live
    )
}

private struct PreviewAIService: AIServicing {
    func generateShotPlan(for prompt: String) async throws -> String {
        "Preview response for: \(prompt)"
    }
}

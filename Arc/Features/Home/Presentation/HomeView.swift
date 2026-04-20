import SwiftUI

struct HomeView: View {
    let aiService: any AIServicing

    var body: some View {
        NavigationStack {
            LocationListView(aiService: aiService)
        }
    }
}

#Preview {
    HomeView(aiService: PreviewAIService())
}

private struct PreviewAIService: AIServicing {
    func generateShotPlan(for prompt: String) async throws -> String {
        "Preview response for: \(prompt)"
    }
}

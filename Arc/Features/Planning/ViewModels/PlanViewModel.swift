import Foundation
import Observation

@MainActor
@Observable
final class PlanViewModel {
    private let aiService: any AIServicing

    var prompt: String = ""
    var response: String = ""
    var errorMessage: String?
    var isLoading: Bool = false

    init(aiService: any AIServicing) {
        self.aiService = aiService
    }

    func generatePlan() async {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty else {
            errorMessage = "Enter a prompt first."
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            response = try await aiService.generateShotPlan(for: cleanPrompt)
        } catch {
            response = ""
            errorMessage = error.localizedDescription
        }
    }

    func applyDefaultPromptIfNeeded(for location: ShootLocation) {
        guard prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        prompt = "Create an 8-shot Instagram carousel plan for \(location.name) at latitude \(location.latitude) and longitude \(location.longitude)."
    }
}

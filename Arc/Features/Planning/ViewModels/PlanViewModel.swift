import Foundation
import Observation

@MainActor
@Observable
final class PlanViewModel {
    private let aiService: any AIServicing
    private let calendar = Calendar.current

    var notes: String = ""
    var response: String = ""
    var errorMessage: String?
    var isLoading: Bool = false
    var shootWindowMode: ShootWindowMode = .now
    var outputIntent: OutputIntent = .instagramCarousel
    var shootDate: Date = Date()
    var shootStartTime: Date = Date()
    var shootEndTime: Date = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()

    init(aiService: any AIServicing) {
        self.aiService = aiService
    }

    var shootWindowSummary: String {
        switch shootWindowMode {
        case .now:
            return "Use the current conditions at the location right now."
        case .custom:
            let window = customShootWindow()
            let dateText = window.start.formatted(date: .abbreviated, time: .omitted)
            let startText = window.start.formatted(date: .omitted, time: .shortened)
            let endText = window.end.formatted(date: .omitted, time: .shortened)
            return "Plan for \(dateText), from \(startText) to \(endText)."
        }
    }

    func generatePlan(for location: ShootLocation) async {
        let prompt = buildPrompt(for: location)
        guard !prompt.isEmpty else {
            errorMessage = "Set up the plan details first."
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            response = try await aiService.generateShotPlan(for: prompt)
        } catch {
            response = ""
            errorMessage = error.localizedDescription
        }
    }

    func ensureDefaultWindowTimes() {
        if shootEndTime <= shootStartTime,
           let adjustedEnd = calendar.date(byAdding: .hour, value: 2, to: shootStartTime) {
            shootEndTime = adjustedEnd
        }
    }

    private func buildPrompt(for location: ShootLocation) -> String {
        guard let shootWindowText = shootWindowPromptText() else {
            return ""
        }

        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let locationCoordinates = "\(location.latitude.formatted(.number.precision(.fractionLength(5)))), \(location.longitude.formatted(.number.precision(.fractionLength(5))))"

        var promptSections = [
            "Create a \(outputIntent.defaultShotCount)-shot plan optimized for a \(outputIntent.promptLabel).",
            "Location: \(location.name) at \(locationCoordinates).",
            "Shoot window: \(shootWindowText).",
            "Each shot should be specific to the location and include a narrative role, composition idea, and practical shooting guidance.",
        ]

        if !cleanNotes.isEmpty {
            promptSections.append("Additional creative notes: \(cleanNotes)")
        }

        return promptSections.joined(separator: "\n")
    }

    private func shootWindowPromptText() -> String? {
        switch shootWindowMode {
        case .now:
            return "right now"
        case .custom:
            let window = customShootWindow()
            guard window.end > window.start else {
                errorMessage = "End time must be after start time."
                return nil
            }

            let startText = window.start.formatted(date: .abbreviated, time: .shortened)
            let endText = window.end.formatted(date: .omitted, time: .shortened)
            return "\(startText) to \(endText)"
        }
    }

    private func customShootWindow() -> (start: Date, end: Date) {
        let start = combine(date: shootDate, time: shootStartTime)
        let end = combine(date: shootDate, time: shootEndTime)
        return (start, end)
    }

    private func combine(date: Date, time: Date) -> Date {
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        let mergedComponents = DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: timeComponents.hour,
            minute: timeComponents.minute
        )

        return calendar.date(from: mergedComponents) ?? date
    }
}

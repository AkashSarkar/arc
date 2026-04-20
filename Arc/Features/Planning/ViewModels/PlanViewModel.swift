import Foundation
import Observation
import SwiftData

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

    init(aiService: any AIServicing, existingPlan: ShootPlan? = nil) {
        self.aiService = aiService

        guard let existingPlan else {
            return
        }

        notes = existingPlan.notes
        response = ShotPlanParser.formattedResponse(
            from: existingPlan.orderedItems.map {
                PlannedShotDraft(title: $0.title, role: $0.role, guidance: $0.guidance)
            },
            fallback: existingPlan.rawResponse
        )
        shootWindowMode = existingPlan.shootWindowMode
        outputIntent = existingPlan.outputIntent
        shootDate = existingPlan.shootDate
        shootStartTime = existingPlan.shootStartTime
        shootEndTime = existingPlan.shootEndTime
    }

    var shootWindowSummary: String {
        switch shootWindowMode {
        case .now:
            return "Use current conditions."
        case .custom:
            let window = customShootWindow()
            let dateText = window.start.formatted(date: .abbreviated, time: .omitted)
            let startText = window.start.formatted(date: .omitted, time: .shortened)
            let endText = window.end.formatted(date: .omitted, time: .shortened)
            return "\(dateText), \(startText) to \(endText)."
        }
    }

    func generatePlan(for location: ShootLocation, modelContext: ModelContext) async {
        let prompt = buildPrompt(for: location)
        guard !prompt.isEmpty else {
            errorMessage = "Set up the plan details first."
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let rawResponse = try await aiService.generateShotPlan(for: prompt)
            let drafts = ShotPlanParser.parse(response: rawResponse)

            persistPlan(
                for: location,
                rawResponse: rawResponse,
                drafts: drafts,
                modelContext: modelContext
            )

            try modelContext.save()
            response = ShotPlanParser.formattedResponse(from: drafts, fallback: rawResponse)
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
        let cachedContextSummary = cachedContextPromptSummary(for: location)

        var promptSections = [
            "Create a \(outputIntent.defaultShotCount)-shot plan optimized for a \(outputIntent.promptLabel).",
            "Location: \(location.name) at \(locationCoordinates).",
            "Shoot window: \(shootWindowText).",
            "Each shot should be specific to the location and include a narrative role, composition idea, and practical shooting guidance.",
            "Return exactly \(outputIntent.defaultShotCount) numbered lines in this format: Short shot title | role | practical guidance.",
            "Do not add headings, intro copy, markdown tables, or closing notes.",
        ]

        if let cachedContextSummary {
            promptSections.append("Use the cached location context below when it helps you choose subjects, angles, sequencing, timing, and lighting. Stay grounded in it and do not invent unsupported details.")
            promptSections.append(cachedContextSummary)
        }

        if !cleanNotes.isEmpty {
            promptSections.append("Additional creative notes: \(cleanNotes)")
        }

        return promptSections.joined(separator: "\n")
    }

    private func cachedContextPromptSummary(for location: ShootLocation) -> String? {
        guard let contextBundle = LocationContextBundle.decode(from: location.enrichmentJSON) else {
            return nil
        }

        var lines: [String] = []

        let highlightSummary = contextBundle.highlights
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)

        if !highlightSummary.isEmpty {
            lines.append("Context highlights: \(Array(highlightSummary).joined(separator: " "))")
        }

        let pointsOfInterestSummary = contextBundle.pointsOfInterest.prefix(5).map { pointOfInterest in
            let category = pointOfInterest.category.lowercased()

            if let distanceMeters = pointOfInterest.distanceMeters {
                return "\(pointOfInterest.name) (\(category), \(Int(distanceMeters.rounded()))m)"
            }

            return "\(pointOfInterest.name) (\(category))"
        }

        if !pointsOfInterestSummary.isEmpty {
            lines.append("Nearby points of interest: \(pointsOfInterestSummary.joined(separator: "; ")).")
        }

        if let wikipedia = contextBundle.wikipedia {
            var wikipediaLine = "Nearby landmark context: \(wikipedia.title)"

            if let detail = normalizedPromptValue(wikipedia.detail) {
                wikipediaLine += " - \(detail)"
            }

            let summary = truncatedPromptText(wikipedia.summary, limit: 220)
            if !summary.isEmpty {
                wikipediaLine += ". \(summary)"
            }

            if let distanceMeters = wikipedia.distanceMeters {
                wikipediaLine += " (\(Int(distanceMeters.rounded()))m away)."
            } else {
                wikipediaLine += "."
            }

            lines.append(wikipediaLine)
        }

        if let weather = contextBundle.weather {
            lines.append("Weather outlook: \(weather.summary)")
        }

        if let sunMoonLine = sunMoonPromptLine(from: contextBundle.sunMoon) {
            lines.append(sunMoonLine)
        }

        if !contextBundle.referenceImages.isEmpty {
            lines.append("Reference imagery: \(contextBundle.referenceImages.count) nearby public reference photos were cached.")
        }

        guard !lines.isEmpty else {
            return nil
        }

        return (["Cached location context:"] + lines).joined(separator: "\n")
    }

    private func sunMoonPromptLine(from sunMoon: LocationSunMoonSummary) -> String? {
        var components: [String] = []

        if let sunrise = sunMoon.sunrise {
            components.append("sunrise \(sunrise.formatted(date: .omitted, time: .shortened))")
        }

        if let sunset = sunMoon.sunset {
            components.append("sunset \(sunset.formatted(date: .omitted, time: .shortened))")
        }

        if let goldenHourMorningStart = sunMoon.goldenHourMorningStart,
           let goldenHourMorningEnd = sunMoon.goldenHourMorningEnd {
            components.append(
                "morning golden hour \(goldenHourMorningStart.formatted(date: .omitted, time: .shortened)) to \(goldenHourMorningEnd.formatted(date: .omitted, time: .shortened))"
            )
        }

        if let goldenHourEveningStart = sunMoon.goldenHourEveningStart,
           let goldenHourEveningEnd = sunMoon.goldenHourEveningEnd {
            components.append(
                "evening golden hour \(goldenHourEveningStart.formatted(date: .omitted, time: .shortened)) to \(goldenHourEveningEnd.formatted(date: .omitted, time: .shortened))"
            )
        }

        components.append("moon \(sunMoon.moonPhaseName), \(Int(sunMoon.moonIlluminationPercent.rounded()))% illumination")

        return components.isEmpty ? nil : "Light and sky: \(components.joined(separator: "; "))."
    }

    private func normalizedPromptValue(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func truncatedPromptText(_ value: String, limit: Int) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.count > limit else {
            return trimmedValue
        }

        let cutoffIndex = trimmedValue.index(trimmedValue.startIndex, offsetBy: limit)
        return String(trimmedValue[..<cutoffIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
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

    private func persistPlan(
        for location: ShootLocation,
        rawResponse: String,
        drafts: [PlannedShotDraft],
        modelContext: ModelContext
    ) {
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = location.plan ?? ShootPlan(location: location)

        if location.plan == nil {
            location.plan = plan
            modelContext.insert(plan)
        }

        plan.createdAt = Date()
        plan.notes = cleanNotes
        plan.rawResponse = rawResponse
        plan.outputIntentRawValue = outputIntent.rawValue
        plan.shootWindowModeRawValue = shootWindowMode.rawValue
        plan.shootWindowSummary = shootWindowSummary
        plan.shootDate = shootDate
        plan.shootStartTime = shootStartTime
        plan.shootEndTime = shootEndTime

        for existingItem in Array(plan.items) {
            modelContext.delete(existingItem)
        }
        plan.items.removeAll()

        for (index, draft) in drafts.enumerated() {
            let item = ShootPlanItem(
                orderIndex: index,
                title: draft.title,
                role: draft.role,
                guidance: draft.guidance,
                plan: plan
            )
            modelContext.insert(item)
            plan.items.append(item)
        }
    }
}

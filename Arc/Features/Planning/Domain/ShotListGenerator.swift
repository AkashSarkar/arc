import Foundation

struct ShotListGenerationInput {
    let outputIntent: OutputIntent
    let captureMedium: CaptureMedium
    let targetPlatform: TargetPlatform
    let stylePreset: CaptureStylePreset
    let notes: String
    let shootWindowMode: ShootWindowMode
    let shootWindowStart: Date
    let shootWindowEnd: Date
}

struct ShotListGenerationResult {
    let prompt: String
    let rawResponse: String
    let drafts: [PlannedShotDraft]
}

@MainActor
protocol ShotListGenerating {
    func generate(for location: Stop, input: ShotListGenerationInput) async throws -> ShotListGenerationResult
}

@MainActor
struct ShotListGenerator: ShotListGenerating {
    private let aiService: any AIServicing

    init(aiService: any AIServicing) {
        self.aiService = aiService
    }

    func generate(for location: Stop, input: ShotListGenerationInput) async throws -> ShotListGenerationResult {
        let prompt = buildPrompt(for: location, input: input)
        let rawResponse = try await aiService.generateShotPlan(for: prompt)
        let drafts = ShotPlanParser.parse(response: rawResponse)

        return ShotListGenerationResult(
            prompt: prompt,
            rawResponse: rawResponse,
            drafts: drafts
        )
    }

    func buildPrompt(for location: Stop, input: ShotListGenerationInput) -> String {
        let shootWindowText = shootWindowPromptText(from: input)
        let cleanNotes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let latitude = location.latitude ?? 0
        let longitude = location.longitude ?? 0
        let locationCoordinates = "\(latitude.formatted(.number.precision(.fractionLength(5)))), \(longitude.formatted(.number.precision(.fractionLength(5))))"
        let cachedContextSummary = cachedContextPromptSummary(for: location)

        var promptSections = [
            "You are a cinematographer and photo director planning a shoot.",
            "Generate a \(input.outputIntent.defaultShotCount)-shot list optimized for a \(input.outputIntent.promptLabel).",
            "Capture medium: \(input.captureMedium.title). \(input.captureMedium.promptDirective)",
            "Target platform: \(input.targetPlatform.title). \(input.targetPlatform.promptDirective)",
            "Creative style: \(input.stylePreset.title). \(input.stylePreset.promptDirective)",
            "Return exactly \(input.outputIntent.defaultShotCount) lines in this exact format:",
            "<short shot title> | <role: establishing/detail/subject/transition/hero/closer> | <practical guidance with composition, focal range, settings hint, timing, and rationale>",
            "Do not return JSON.",
            "Do not return markdown.",
            "Do not include headings or intro/outro text.",
            "Location: \(location.name) at \(locationCoordinates).",
            "Shoot window: \(shootWindowText).",
            "Each shot must be specific to this location and include practical field guidance."
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

    private func shootWindowPromptText(from input: ShotListGenerationInput) -> String {
        if input.shootWindowMode == .now {
            return "right now"
        }

        let startText = input.shootWindowStart.formatted(date: .abbreviated, time: .shortened)
        let endText = input.shootWindowEnd.formatted(date: .omitted, time: .shortened)
        return "\(startText) to \(endText)"
    }

    private func cachedContextPromptSummary(for location: Stop) -> String? {
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
}

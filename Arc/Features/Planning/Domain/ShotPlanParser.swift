import Foundation

struct PlannedShotDraft {
    let title: String
    let role: String
    let guidance: String
}

enum ShotPlanParser {
    static func parse(response: String) -> [PlannedShotDraft] {
        if let jsonDrafts = parseJSONResponse(response), !jsonDrafts.isEmpty {
            return jsonDrafts
        }

        let candidateLines = response
            .components(separatedBy: .newlines)
            .map(cleanedLine)
            .filter { !$0.isEmpty && isLikelyShotLine($0) }

        let parsedLines = candidateLines.compactMap(parseLine)
        if !parsedLines.isEmpty {
            return parsedLines
        }

        return fallbackDrafts(from: response)
    }

    static func formattedResponse(from drafts: [PlannedShotDraft], fallback: String) -> String {
        guard !drafts.isEmpty else {
            return fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return drafts.enumerated().map { index, draft in
            "\(index + 1). \(draft.title)\nRole: \(draft.role)\nGuidance: \(draft.guidance)"
        }
        .joined(separator: "\n\n")
    }

    private static func parseJSONResponse(_ response: String) -> [PlannedShotDraft]? {
        guard let jsonData = extractJSONObjectData(from: response) else {
            return nil
        }

        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(ShotPlanPayload.self, from: jsonData) else {
            return nil
        }

        return payload.shots.map { shot in
            let title = normalizedTitle(from: shot.description)
            let guidanceComponents = [
                "Composition: \(shot.compositionNote)",
                "Lens: \(shot.focalLengthMin)-\(shot.focalLengthMax)mm",
                "Settings: \(shot.settingsHint)",
                "Timing: \(shot.timeWindowLabel)",
                "Why: \(shot.rationale)",
            ]

            return PlannedShotDraft(
                title: title,
                role: shot.role.capitalized,
                guidance: guidanceComponents.joined(separator: " • ")
            )
        }
    }

    private static func extractJSONObjectData(from response: String) -> Data? {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let normalized = trimmed
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let startIndex = normalized.firstIndex(of: "{"),
              let endIndex = normalized.lastIndex(of: "}")
        else {
            return nil
        }

        let jsonSubstring = normalized[startIndex...endIndex]
        return String(jsonSubstring).data(using: .utf8)
    }

    private static func normalizedTitle(from description: String) -> String {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Untitled Shot"
        }

        if let separatorRange = trimmed.range(of: ":") {
            let candidate = trimmed[..<separatorRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            if candidate.count >= 4 {
                return candidate
            }
        }

        return trimmed.count > 70 ? String(trimmed.prefix(70)).trimmingCharacters(in: .whitespacesAndNewlines) + "..." : trimmed
    }

    private static func cleanedLine(_ rawLine: String) -> String {
        var cleaned = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(
            of: "^\\s*(?:[-*•]|\\d+[.)])\\s*",
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(of: "[*_`]", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isLikelyShotLine(_ line: String) -> Bool {
        if line.contains("|") {
            return true
        }

        if line.count < 12 {
            return false
        }

        let lowercasedLine = line.lowercased()
        return lowercasedLine.contains("shot")
            || lowercasedLine.contains("frame")
            || lowercasedLine.contains("angle")
            || lowercasedLine.contains("detail")
            || lowercasedLine.contains("wide")
            || lowercasedLine.contains("hero")
            || lowercasedLine.contains("vertical")
    }

    private static func parseLine(_ line: String) -> PlannedShotDraft? {
        let pipeSeparatedParts = line
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { sanitizedField(String($0)) }

        if pipeSeparatedParts.count >= 3 {
            let title = pipeSeparatedParts[0]
            let role = pipeSeparatedParts[1]
            let guidance = pipeSeparatedParts[2...].joined(separator: " | ")

            guard !title.isEmpty, !guidance.isEmpty else {
                return nil
            }

            return PlannedShotDraft(
                title: title,
                role: role.isEmpty ? inferredRole(from: title) : role,
                guidance: guidance
            )
        }

        for separator in [" — ", " – ", " - "] {
            let parts = line.components(separatedBy: separator).map(sanitizedField)
            if parts.count >= 2 {
                let title = parts[0]
                let guidance = parts[1...].joined(separator: separator)

                guard !title.isEmpty, !guidance.isEmpty else {
                    continue
                }

                return PlannedShotDraft(
                    title: title,
                    role: inferredRole(from: title),
                    guidance: guidance
                )
            }
        }

        return nil
    }

    private static func fallbackDrafts(from response: String) -> [PlannedShotDraft] {
        response
            .components(separatedBy: .newlines)
            .map(cleanedLine)
            .filter { !$0.isEmpty }
            .prefix(8)
            .map { line in
                if let parsedLine = parseLine(line) {
                    return parsedLine
                }

                return PlannedShotDraft(
                    title: fallbackTitle(from: line),
                    role: inferredRole(from: line),
                    guidance: line
                )
            }
    }

    private static func sanitizedField(_ field: String) -> String {
        field
            .replacingOccurrences(
                of: "^(?:title|role|guidance)\\s*:\\s*",
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fallbackTitle(from line: String) -> String {
        let separators = [":", ",", "."]
        for separator in separators {
            if let prefix = line.components(separatedBy: separator).first?.trimmingCharacters(in: .whitespacesAndNewlines),
               !prefix.isEmpty {
                return prefix
            }
        }

        return line
    }

    private static func inferredRole(from text: String) -> String {
        let lowercasedText = text.lowercased()

        if lowercasedText.contains("wide") || lowercasedText.contains("establish") {
            return "Wide"
        }

        if lowercasedText.contains("hero") || lowercasedText.contains("main") {
            return "Hero"
        }

        if lowercasedText.contains("detail") || lowercasedText.contains("texture") || lowercasedText.contains("close") {
            return "Detail"
        }

        if lowercasedText.contains("vertical") || lowercasedText.contains("motion") || lowercasedText.contains("cutaway") {
            return "Motion"
        }

        if lowercasedText.contains("closer") || lowercasedText.contains("closing") || lowercasedText.contains("finish") {
            return "Closer"
        }

        return "Support"
    }
}

private struct ShotPlanPayload: Decodable {
    let shots: [ShotPlanJSONShot]
}

private struct ShotPlanJSONShot: Decodable {
    let sequence: Int
    let role: String
    let description: String
    let compositionNote: String
    let focalLengthMin: Int
    let focalLengthMax: Int
    let settingsHint: String
    let timeWindowLabel: String
    let rationale: String

    enum CodingKeys: String, CodingKey {
        case sequence
        case role
        case description
        case compositionNote = "composition_note"
        case focalLengthMin = "focal_length_min"
        case focalLengthMax = "focal_length_max"
        case settingsHint = "settings_hint"
        case timeWindowLabel = "time_window_label"
        case rationale
    }
}

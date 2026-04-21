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
        guard let jsonRoot = parseJSONRoot(from: response) else {
            return nil
        }

        if let shots = extractShotsArray(from: jsonRoot) {
            let drafts = shots.compactMap(parseJSONShot)
            return drafts.isEmpty ? nil : drafts
        }

        return nil
    }

    private static func parseJSONRoot(from response: String) -> Any? {
        let normalized = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return nil
        }

        if let directObject = parseJSONObject(from: normalized) {
            return unwrapJSONContainer(directObject)
        }

        if let start = normalized.firstIndex(of: "{"),
           let end = normalized.lastIndex(of: "}") {
            let objectSlice = String(normalized[start...end])
            if let slicedObject = parseJSONObject(from: objectSlice) {
                return unwrapJSONContainer(slicedObject)
            }
        }

        if let start = normalized.firstIndex(of: "["),
           let end = normalized.lastIndex(of: "]") {
            let arraySlice = String(normalized[start...end])
            if let slicedArray = parseJSONObject(from: arraySlice) {
                return unwrapJSONContainer(slicedArray)
            }
        }

        return nil
    }

    private static func parseJSONObject(from string: String) -> Any? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }

        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func unwrapJSONContainer(_ object: Any) -> Any {
        if let dictionary = object as? [String: Any] {
            if let shots = dictionary["shots"] {
                return ["shots": shots]
            }

            for key in ["data", "response", "content", "result", "output", "message", "choices"] {
                if let nested = dictionary[key] {
                    return unwrapJSONContainer(nested)
                }
            }

            return dictionary
        }

        if let string = object as? String,
           let nestedObject = parseJSONObject(from: string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return unwrapJSONContainer(nestedObject)
        }

        return object
    }

    private static func extractShotsArray(from root: Any) -> [Any]? {
        if let dictionary = root as? [String: Any] {
            if let shots = dictionary["shots"] as? [Any] {
                return shots
            }

            if let plan = dictionary["plan"] as? [String: Any],
               let shots = plan["shots"] as? [Any] {
                return shots
            }

            if let items = dictionary["items"] as? [Any] {
                return items
            }

            if let drafts = dictionary["drafts"] as? [Any] {
                return drafts
            }

            return nil
        }

        if let array = root as? [Any] {
            return array
        }

        return nil
    }

    private static func parseJSONShot(_ rawValue: Any) -> PlannedShotDraft? {
        if let dictionary = rawValue as? [String: Any] {
            if let nestedShot = dictionary["shot"] as? [String: Any] {
                return parseJSONShot(nestedShot)
            }

            let titleOrDescription = firstNonEmptyString(
                dictionary["title"],
                dictionary["name"],
                dictionary["description"],
                dictionary["shot_description"]
            )

            let role = firstNonEmptyString(
                dictionary["role"],
                dictionary["narrative_role"],
                dictionary["type"]
            ) ?? "Support"

            let composition = firstNonEmptyString(dictionary["composition_note"], dictionary["compositionNote"]) ?? ""
            let settings = firstNonEmptyString(dictionary["settings_hint"], dictionary["settingsHint"]) ?? ""
            let timing = firstNonEmptyString(dictionary["time_window_label"], dictionary["timeWindowLabel"], dictionary["time_of_day"]) ?? ""
            let rationale = firstNonEmptyString(dictionary["rationale"], dictionary["why"]) ?? ""
            let directGuidance = firstNonEmptyString(
                dictionary["guidance"],
                dictionary["practical_guidance"],
                dictionary["instructions"],
                dictionary["notes"],
                dictionary["note"]
            ) ?? ""
            let focalMin = firstIntValue(dictionary["focal_length_min"], dictionary["focalLengthMin"])
            let focalMax = firstIntValue(dictionary["focal_length_max"], dictionary["focalLengthMax"])

            let title = normalizedTitle(from: titleOrDescription ?? "")

            var guidanceComponents: [String] = []
            if !composition.isEmpty {
                guidanceComponents.append("Composition: \(composition)")
            }

            if let focalMin, let focalMax {
                guidanceComponents.append("Lens: \(focalMin)-\(focalMax)mm")
            } else if let focalMin {
                guidanceComponents.append("Lens: \(focalMin)mm+")
            } else if let focalMax {
                guidanceComponents.append("Lens: up to \(focalMax)mm")
            }

            if !settings.isEmpty {
                guidanceComponents.append("Settings: \(settings)")
            }

            if !timing.isEmpty {
                guidanceComponents.append("Timing: \(timing)")
            }

            if !rationale.isEmpty {
                guidanceComponents.append("Why: \(rationale)")
            }

            if guidanceComponents.isEmpty, !directGuidance.isEmpty {
                guidanceComponents.append(directGuidance)
            }

            if guidanceComponents.isEmpty, let titleOrDescription, !titleOrDescription.isEmpty {
                guidanceComponents.append(titleOrDescription)
            }

            let guidance = guidanceComponents.joined(separator: " • ")
            guard !title.isEmpty, !guidance.isEmpty else {
                return nil
            }

            return PlannedShotDraft(
                title: title,
                role: role.capitalized,
                guidance: guidance
            )
        }

        if let line = rawValue as? String {
            return parseLine(cleanedLine(line))
        }

        return nil
    }

    private static func firstNonEmptyString(_ values: Any?...) -> String? {
        for value in values {
            if let string = value as? String {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }

        return nil
    }

    private static func firstIntValue(_ values: Any?...) -> Int? {
        for value in values {
            if let intValue = value as? Int {
                return intValue
            }

            if let doubleValue = value as? Double {
                return Int(doubleValue.rounded())
            }

            if let stringValue = value as? String {
                let digitsOnly = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if let parsedValue = Int(digitsOnly) {
                    return parsedValue
                }
            }
        }

        return nil
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

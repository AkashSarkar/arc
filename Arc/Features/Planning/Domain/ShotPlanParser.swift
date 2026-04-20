import Foundation

struct PlannedShotDraft {
    let title: String
    let role: String
    let guidance: String
}

enum ShotPlanParser {
    static func parse(response: String) -> [PlannedShotDraft] {
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
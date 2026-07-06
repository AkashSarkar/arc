import Foundation

enum ImportedPlanParser {
    static func parse(title: String, text: String) -> FieldGuideDraft {
        let lines = normalizedLines(from: text)
        guard !lines.isEmpty else {
            return FieldGuideDraft(title: title, storySummary: "", stages: [])
        }

        var stages: [FieldGuideStageDraft] = []
        var currentStage: FieldGuideStageDraft?
        var currentSectionIsBeforeLeaving = false

        for rawLine in lines {
            let cleaned = cleanedLine(rawLine)
            guard !cleaned.isEmpty else {
                continue
            }

            if isBeforeLeavingHeading(cleaned) {
                currentSectionIsBeforeLeaving = true
                if currentStage == nil {
                    currentStage = FieldGuideStageDraft(title: "Field Check")
                }
                continue
            }

            if isLikelyStageHeading(rawLine, cleaned: cleaned) {
                if let finishedStage = currentStage, !finishedStage.items.isEmpty {
                    stages.append(stageWithLeavingFallback(finishedStage))
                }

                currentStage = FieldGuideStageDraft(title: stageTitle(from: cleaned))
                currentSectionIsBeforeLeaving = false
                continue
            }

            if currentStage == nil {
                currentStage = FieldGuideStageDraft(title: "Start")
            }

            guard let item = itemDraft(from: cleaned, inheritedBeforeLeaving: currentSectionIsBeforeLeaving) else {
                continue
            }

            currentStage?.items.append(item)
        }

        if let finishedStage = currentStage, !finishedStage.items.isEmpty {
            stages.append(stageWithLeavingFallback(finishedStage))
        }

        if stages.isEmpty {
            stages = chunkedFallbackStages(from: lines.map(cleanedLine))
        }

        return FieldGuideDraft(
            title: title,
            storySummary: summary(from: text),
            stages: stages
        )
    }

    private static func normalizedLines(from text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func cleanedLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: "^#{1,6}\\s*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^\\s*(?:[-*•]|\\d+[.)])\\s*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[*_`]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isLikelyStageHeading(_ rawLine: String, cleaned: String) -> Bool {
        let lowercased = cleaned.lowercased()
        let wordCount = cleaned.split(separator: " ").count
        let isBullet = rawLine.range(of: "^\\s*(?:[-*•]|\\d+[.)])\\s+", options: .regularExpression) != nil

        if cleaned.hasSuffix(":") {
            return true
        }

        if lowercased.range(of: #"^(day|stage|scene|part)\s+\d+"#, options: .regularExpression) != nil {
            return true
        }

        if lowercased.range(of: #"^\d{1,2}(:\d{2})?\s*(am|pm)\b"#, options: .regularExpression) != nil {
            return true
        }

        if !isBullet,
           wordCount <= 7,
           !cleaned.contains("."),
           !cleaned.contains("?"),
           !lowercased.hasPrefix("capture "),
           !lowercased.hasPrefix("film "),
           !lowercased.hasPrefix("record "),
           !lowercased.hasPrefix("shoot ") {
            return true
        }

        return false
    }

    private static func isBeforeLeavingHeading(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        return lowercased.contains("before leaving")
            || lowercased.contains("before you leave")
            || lowercased.contains("before moving on")
    }

    private static func stageTitle(from line: String) -> String {
        line.trimmingCharacters(in: CharacterSet(charactersIn: ":").union(.whitespacesAndNewlines))
    }

    private static func itemDraft(from line: String, inheritedBeforeLeaving: Bool) -> FieldGuideItemDraft? {
        let title = titleText(from: line)
        guard !title.isEmpty else {
            return nil
        }

        let lowercased = line.lowercased()
        let kind = inferredKind(from: lowercased)
        let isBeforeLeaving = inheritedBeforeLeaving
            || lowercased.contains("before leaving")
            || lowercased.contains("before you leave")
            || lowercased.contains("leaving shot")
            || lowercased.contains("departure")
            || lowercased.contains("checkout")

        return FieldGuideItemDraft(
            title: title,
            guidance: guidanceText(from: line, fallbackTitle: title),
            kind: kind,
            priority: inferredPriority(from: lowercased, isBeforeLeaving: isBeforeLeaving),
            isBeforeLeaving: isBeforeLeaving
        )
    }

    private static func titleText(from line: String) -> String {
        for separator in [" - ", " — ", " – ", ":"] {
            if let firstPart = line.components(separatedBy: separator).first?.trimmingCharacters(in: .whitespacesAndNewlines),
               !firstPart.isEmpty,
               firstPart.count <= 72 {
                return firstPart
            }
        }

        return line.count > 72 ? String(line.prefix(72)).trimmingCharacters(in: .whitespacesAndNewlines) : line
    }

    private static func guidanceText(from line: String, fallbackTitle: String) -> String {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLine == fallbackTitle ? "Capture this clearly enough to use in the edit." : trimmedLine
    }

    private static func inferredKind(from lowercased: String) -> FieldGuideItemKind {
        if lowercased.contains("voice") || lowercased.contains("say ") || lowercased.contains("line to camera") || lowercased.contains("reaction") {
            return .voice
        }

        if lowercased.contains("sound") || lowercased.contains("audio") || lowercased.contains("ambient") || lowercased.contains("natural sound") {
            return .sound
        }

        if lowercased.contains("transition") || lowercased.contains("leaving") || lowercased.contains("arriving") || lowercased.contains("departure") {
            return .transition
        }

        if lowercased.contains("note") || lowercased.contains("remember") {
            return .note
        }

        return .shot
    }

    private static func inferredPriority(from lowercased: String, isBeforeLeaving: Bool) -> FieldGuidePriority {
        if isBeforeLeaving
            || lowercased.contains("must")
            || lowercased.contains("important")
            || lowercased.contains("ending")
            || lowercased.contains("beginning")
            || lowercased.contains("establish") {
            return .must
        }

        if lowercased.contains("optional") || lowercased.contains("nice to") {
            return .optional
        }

        return .must
    }

    private static func stageWithLeavingFallback(_ stage: FieldGuideStageDraft) -> FieldGuideStageDraft {
        guard !stage.items.contains(where: \.isBeforeLeaving) else {
            return stage
        }

        var updatedStage = stage
        updatedStage.items.append(
            FieldGuideItemDraft(
                title: "Leaving transition",
                guidance: "Before moving on, capture one shot that shows you leaving or changing location.",
                kind: .transition,
                priority: .optional,
                isBeforeLeaving: true
            )
        )
        return updatedStage
    }

    private static func chunkedFallbackStages(from lines: [String]) -> [FieldGuideStageDraft] {
        let itemDrafts = lines.compactMap { itemDraft(from: $0, inheritedBeforeLeaving: false) }
        return stride(from: 0, to: itemDrafts.count, by: 8).map { startIndex in
            let endIndex = min(startIndex + 8, itemDrafts.count)
            return stageWithLeavingFallback(
                FieldGuideStageDraft(
                    title: startIndex == 0 ? "Start" : "Stage \(startIndex / 8 + 1)",
                    items: Array(itemDrafts[startIndex ..< endIndex])
                )
            )
        }
    }

    private static func summary(from text: String) -> String {
        let words = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .split(separator: " ")

        guard !words.isEmpty else {
            return ""
        }

        return words.prefix(28).joined(separator: " ")
    }
}

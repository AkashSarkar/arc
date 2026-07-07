import Foundation

nonisolated enum ImportedPlanParser {
    static func parse(title: String, text: String) -> FieldGuideDraft {
        parseDocument(title: title, text: text).fieldGuideDraft
    }

    static func parseDocument(title: String, text: String) -> ArcPlanDocument {
        T0PlanParser(title: title, text: text).parse()
    }

    static func dayChunks(title: String, text: String) -> [(title: String, text: String)] {
        let lines = normalizedLines(from: text)
        var chunks: [(title: String, lines: [String])] = []
        var currentTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var currentLines: [String] = []

        for line in lines {
            let cleaned = cleanedLine(line)
            if isDayHeading(line, cleaned: cleaned) {
                if !currentLines.isEmpty {
                    chunks.append((title: currentTitle.isEmpty ? "Day \(chunks.count + 1)" : currentTitle, lines: currentLines))
                }
                currentTitle = dayTitle(from: cleaned, fallbackIndex: chunks.count + 1)
                currentLines = [line]
            } else {
                currentLines.append(line)
            }
        }

        if !currentLines.isEmpty {
            chunks.append((title: currentTitle.isEmpty ? title : currentTitle, lines: currentLines))
        }

        return chunks.map { ($0.title, $0.lines.joined(separator: "\n")) }
    }

    static func normalizedLines(from text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func cleanedLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: "^#{1,6}\\s*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^\\s*(?:[-*•]|\\d+[.)])\\s*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[*_`]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isDayHeading(_ rawLine: String, cleaned: String) -> Bool {
        let lowercased = cleaned.lowercased()
        guard rawLine.hasPrefix("##") || lowercased.range(of: #"^(day|stage|scene|part)\s+\d+"#, options: .regularExpression) != nil else {
            return false
        }

        return lowercased.range(of: #"^(day|stage|scene|part)\s+\d+"#, options: .regularExpression) != nil
    }

    static func dayTitle(from cleaned: String, fallbackIndex: Int) -> String {
        let trimmed = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ":").union(.whitespacesAndNewlines))
        return trimmed.isEmpty ? "Day \(fallbackIndex)" : trimmed
    }
}

private nonisolated struct T0PlanParser {
    private let providedTitle: String
    private let sourceText: String
    private let lines: [String]

    init(title: String, text: String) {
        self.providedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceText = text
        self.lines = ImportedPlanParser.normalizedLines(from: text)
    }

    func parse() -> ArcPlanDocument {
        let title = planTitle()
        var days: [ArcShootDayDocument] = []
        var currentDay: ArcShootDayDocument?
        var currentStop: ArcStopDocument?
        var currentStage: ArcStageDocument?
        var unparsedRemainder: [String] = []

        func finishStage() {
            guard let stage = currentStage else {
                return
            }

            guard !stage.items.isEmpty else {
                currentStage = nil
                return
            }

            if currentStop == nil {
                currentStop = ArcStopDocument(title: title, placeName: title)
            }

            currentStop?.stages.append(stage)
            currentStage = nil
        }

        func finishStop() {
            finishStage()
            guard var stop = currentStop else {
                return
            }

            addSyntheticBeforeLeavingIfNeeded(to: &stop)

            if currentDay == nil {
                currentDay = ArcShootDayDocument(title: "Day 1")
            }

            currentDay?.stops.append(stop)
            currentStop = nil
        }

        func finishDay() {
            finishStop()
            guard let day = currentDay else {
                return
            }

            guard !day.stops.isEmpty else {
                currentDay = nil
                return
            }

            days.append(day)
            currentDay = nil
        }

        for rawLine in lines {
            let cleaned = ImportedPlanParser.cleanedLine(rawLine)
            guard !cleaned.isEmpty else {
                continue
            }

            if isTopLevelTitle(rawLine) {
                continue
            }

            if ImportedPlanParser.isDayHeading(rawLine, cleaned: cleaned) {
                finishDay()
                currentDay = ArcShootDayDocument(title: ImportedPlanParser.dayTitle(from: cleaned, fallbackIndex: days.count + 1))
                currentStop = nil
                currentStage = nil
                continue
            }

            if let stopTitle = explicitStopTitle(from: rawLine, cleaned: cleaned) {
                finishStop()
                currentStop = ArcStopDocument(title: stopTitle, placeName: stopTitle)
                if currentDay == nil {
                    currentDay = ArcShootDayDocument(title: "Day \(days.count + 1)")
                }
                continue
            }

            if let timedStopTitle = timedStopTitle(from: cleaned) {
                finishStop()
                currentStop = ArcStopDocument(
                    title: timedStopTitle,
                    placeName: timedStopTitle,
                    geo: ArcGeoDocument(sourceAnchor: rawLine)
                )
                if currentDay == nil {
                    currentDay = ArcShootDayDocument(title: "Day \(days.count + 1)")
                }
                continue
            }

            let stopAwaitingGeo = currentStop != nil && currentStage == nil
                && (currentStop?.geo?.sourceAnchor ?? "").isEmpty
            if currentStop != nil, currentStage == nil,
               isGeoAnchor(rawLine) || (stopAwaitingGeo && isLikelyAddressLine(rawLine)) {
                var geo = currentStop?.geo ?? ArcGeoDocument()
                geo.sourceAnchor = rawLine
                geo.resolved = false
                currentStop?.geo = geo
                continue
            }

            if isBeforeLeavingHeading(cleaned) {
                finishStage()
                if currentStop == nil {
                    currentStop = ArcStopDocument(title: title, placeName: title)
                }
                currentStage = ArcStageDocument(
                    title: "Before You Leave",
                    goal: "Leave with the story safely covered.",
                    kind: .beforeLeaving
                )
                continue
            }

            if isLikelyStageHeading(rawLine, cleaned: cleaned) {
                finishStage()
                if currentStop == nil {
                    currentStop = ArcStopDocument(title: title, placeName: title)
                }
                let stageTitle = stageTitle(from: cleaned)
                currentStage = ArcStageDocument(
                    title: stageTitle,
                    goal: defaultGoal(for: stageTitle),
                    kind: .standard
                )
                continue
            }

            if currentStop == nil {
                currentStop = ArcStopDocument(title: title, placeName: title)
            }

            if currentStage == nil {
                currentStage = ArcStageDocument(title: "Start", goal: defaultGoal(for: "Start"), kind: .standard)
            }

            if let item = itemDocument(from: rawLine, cleaned: cleaned, inBeforeLeavingStage: currentStage?.kind == .beforeLeaving) {
                currentStage?.items.append(item)
            } else {
                unparsedRemainder.append(rawLine)
            }
        }

        finishDay()

        if days.isEmpty {
            days = fallbackDays(title: title, lines: lines)
        }

        let trip = ArcTripDocument(
            title: title,
            summary: summary(from: sourceText),
            brief: ArcTripBriefDocument(
                outputIntent: OutputIntent.fullTravelVlog.rawValue,
                captureMedium: CaptureMedium.hybrid.rawValue,
                targetPlatform: TargetPlatform.youtube.rawValue,
                stylePreset: CaptureStylePreset.natural.rawValue
            ),
            artifacts: [
                ArcTripArtifactDocument(kind: .shootList, title: "Imported Plan", body: sourceText)
            ],
            days: days
        )

        return ArcPlanDocument(
            kind: .plan,
            generator: "Arc/1.0 (import-t0)",
            sourceText: sourceText,
            unparsedRemainder: unparsedRemainder,
            trip: trip,
            execution: nil
        )
    }

    private func planTitle() -> String {
        for line in lines {
            guard line.hasPrefix("# "), !line.hasPrefix("##") else {
                continue
            }

            let title = ImportedPlanParser.cleanedLine(line)
            if !title.isEmpty {
                return title
            }
        }

        return providedTitle.isEmpty ? "Imported Plan" : providedTitle
    }

    private func isTopLevelTitle(_ rawLine: String) -> Bool {
        rawLine.hasPrefix("# ") && !rawLine.hasPrefix("##")
    }

    private func explicitStopTitle(from rawLine: String, cleaned: String) -> String? {
        let lowercased = cleaned.lowercased()
        guard rawLine.hasPrefix("###") || lowercased.hasPrefix("stop:") else {
            return nil
        }

        let title = cleaned
            .replacingOccurrences(of: #"^stop\s*:?\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: CharacterSet(charactersIn: ":").union(.whitespacesAndNewlines))

        return title.isEmpty ? nil : title
    }

    private func timedStopTitle(from cleaned: String) -> String? {
        let pattern = #"^\d{1,2}(:\d{2})?\s*(am|pm)?\s*[-–—]\s*(.+)$"#
        guard let match = cleaned.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }

        let matched = String(cleaned[match])
        let title = matched
            .replacingOccurrences(of: #"^\d{1,2}(:\d{2})?\s*(am|pm)?\s*[-–—]\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return title.isEmpty ? nil : title
    }

    private func isGeoAnchor(_ rawLine: String) -> Bool {
        let lowercased = rawLine.lowercased()
        if lowercased.contains("maps.google.com")
            || lowercased.contains("goo.gl/maps")
            || lowercased.contains("maps.app.goo.gl") {
            return true
        }

        guard !rawLine.hasPrefix("#"),
              rawLine.range(of: "^\\s*(?:[-*•]|\\d+[.)])\\s+", options: .regularExpression) == nil
        else {
            return false
        }

        let hasDigit = rawLine.rangeOfCharacter(from: .decimalDigits) != nil
        let hasAddressSeparator = rawLine.contains(",") || lowercased.range(of: #"\b\d{3,}\b"#, options: .regularExpression) != nil
        return hasDigit && hasAddressSeparator && rawLine.count <= 140
    }

    // Digit-less addresses ("Rua da Conceição, Lisboa") are only trusted while a stop is
    // still waiting for its first geo anchor, so prose lines elsewhere stay untouched.
    private func isLikelyAddressLine(_ rawLine: String) -> Bool {
        guard !rawLine.hasPrefix("#"),
              !rawLine.hasSuffix(":"),
              rawLine.range(of: "^\\s*(?:[-*•]|\\d+[.)])\\s+", options: .regularExpression) == nil
        else {
            return false
        }

        return rawLine.contains(",") && rawLine.count <= 80 && rawLine.split(separator: " ").count <= 8
    }

    private func isLikelyStageHeading(_ rawLine: String, cleaned: String) -> Bool {
        let lowercased = cleaned.lowercased()
        let wordCount = cleaned.split(separator: " ").count
        let isBullet = rawLine.range(of: "^\\s*(?:[-*•]|\\d+[.)])\\s+", options: .regularExpression) != nil

        if cleaned.hasSuffix(":") {
            return true
        }

        if lowercased.range(of: #"^(day|stage|scene|part)\s+\d+"#, options: .regularExpression) != nil {
            return false
        }

        if lowercased.hasPrefix("stop:") || isGeoAnchor(rawLine) {
            return false
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

    private func isBeforeLeavingHeading(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        return lowercased.contains("before leaving")
            || lowercased.contains("before you leave")
            || lowercased.contains("before moving on")
    }

    private func stageTitle(from line: String) -> String {
        line.trimmingCharacters(in: CharacterSet(charactersIn: ":").union(.whitespacesAndNewlines))
    }

    private func defaultGoal(for stageTitle: String) -> String {
        "Capture the \(stageTitle.lowercased()) beat clearly enough to carry the edit."
    }

    private func itemDocument(from rawLine: String, cleaned: String, inBeforeLeavingStage: Bool) -> ArcCaptureItemDocument? {
        var itemText = cleaned
        guard !itemText.isEmpty else {
            return nil
        }

        let kind = explicitKind(from: &itemText) ?? inferredKind(from: itemText.lowercased())
        let explicitPriority = stripPriorityMarker(from: &itemText)
        let beforeLeaving = inBeforeLeavingStage || isBeforeLeavingItem(itemText.lowercased())
        let priority = beforeLeaving ? ArcCapturePriority.must : (explicitPriority ?? inferredPriority(from: itemText.lowercased()))
        let title = titleText(from: itemText)
        guard !title.isEmpty else {
            return nil
        }

        return ArcCaptureItemDocument(
            title: title,
            guidance: guidanceText(from: itemText, fallbackTitle: title),
            itemKind: kind,
            priority: priority,
            beforeLeaving: beforeLeaving,
            sourceLine: rawLine
        )
    }

    private func explicitKind(from itemText: inout String) -> ArcCaptureItemKind? {
        let patterns: [(String, ArcCaptureItemKind)] = [
            ("voice", .voice),
            ("sound", .sound),
            ("transition", .transition),
            ("note", .note)
        ]

        for (prefix, kind) in patterns {
            let pattern = #"^\#(prefix)\s*:\s*"#
            if itemText.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                itemText = itemText.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
                return kind
            }
        }

        return nil
    }

    private func stripPriorityMarker(from itemText: inout String) -> ArcCapturePriority? {
        let lowercased = itemText.lowercased()
        let priority: ArcCapturePriority?
        if lowercased.range(of: #"\(\s*must\s*\)\s*$"#, options: .regularExpression) != nil {
            priority = .must
        } else if lowercased.range(of: #"\(\s*optional\s*\)\s*$"#, options: .regularExpression) != nil {
            priority = .optional
        } else {
            priority = nil
        }

        itemText = itemText
            .replacingOccurrences(of: #"\s*\(\s*(must|optional)\s*\)\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return priority
    }

    private func titleText(from line: String) -> String {
        for separator in [" - ", " — ", " – ", ":"] {
            if let firstPart = line.components(separatedBy: separator).first?.trimmingCharacters(in: .whitespacesAndNewlines),
               !firstPart.isEmpty,
               firstPart.count <= 72 {
                return firstPart
            }
        }

        return line.count > 72 ? String(line.prefix(72)).trimmingCharacters(in: .whitespacesAndNewlines) : line
    }

    private func guidanceText(from line: String, fallbackTitle: String) -> String {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLine == fallbackTitle ? "Capture this clearly enough to use in the edit." : trimmedLine
    }

    private func inferredKind(from lowercased: String) -> ArcCaptureItemKind {
        if lowercased.contains("voice") || lowercased.contains("say ") || lowercased.contains("line to camera") || lowercased.contains("reaction") {
            return .voice
        }

        if lowercased.contains("sound") || lowercased.contains("audio") || lowercased.contains("ambien") || lowercased.contains("ambian") {
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

    private func inferredPriority(from lowercased: String) -> ArcCapturePriority {
        if lowercased.contains("optional") || lowercased.contains("nice to") {
            return .optional
        }

        return .must
    }

    private func isBeforeLeavingItem(_ lowercased: String) -> Bool {
        lowercased.contains("before leaving")
            || lowercased.contains("before you leave")
            || lowercased.contains("leaving shot")
            || lowercased.contains("departure")
            || lowercased.contains("checkout")
    }

    private func addSyntheticBeforeLeavingIfNeeded(to stop: inout ArcStopDocument) {
        let hasBeforeLeavingItem = stop.stages.flatMap(\.items).contains { $0.beforeLeaving }
        guard !hasBeforeLeavingItem else {
            return
        }

        stop.stages.append(
            ArcStageDocument(
                title: "Before You Leave",
                goal: "Leave with the story safely covered.",
                kind: .beforeLeaving,
                items: [
                    ArcCaptureItemDocument(
                        title: "Leaving transition",
                        guidance: "Before moving on, capture one shot that shows you leaving or changing location.",
                        itemKind: .transition,
                        priority: .must,
                        beforeLeaving: true,
                        sourceLine: "",
                        synthetic: true
                    )
                ]
            )
        )
    }

    private func fallbackDays(title: String, lines: [String]) -> [ArcShootDayDocument] {
        let items = lines.compactMap {
            itemDocument(from: $0, cleaned: ImportedPlanParser.cleanedLine($0), inBeforeLeavingStage: false)
        }

        let stages = stride(from: 0, to: items.count, by: 8).map { startIndex in
            let endIndex = min(startIndex + 8, items.count)
            return ArcStageDocument(
                title: startIndex == 0 ? "Start" : "Stage \(startIndex / 8 + 1)",
                goal: defaultGoal(for: startIndex == 0 ? "Start" : "Stage \(startIndex / 8 + 1)"),
                kind: .standard,
                items: Array(items[startIndex ..< endIndex])
            )
        }

        var stop = ArcStopDocument(title: title, placeName: title, stages: stages)
        addSyntheticBeforeLeavingIfNeeded(to: &stop)
        return [ArcShootDayDocument(title: "Day 1", stops: [stop])]
    }

    private func summary(from text: String) -> String {
        let words = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .split(separator: " ")

        guard !words.isEmpty else {
            return ""
        }

        return words.prefix(28).joined(separator: " ")
    }
}

nonisolated extension ArcPlanDocument {
    var fieldGuideDraft: FieldGuideDraft {
        let stages = trip.days.enumerated().flatMap { dayIndex, day in
            day.stops.enumerated().flatMap { stopIndex, stop in
                stop.stages.enumerated().map { stageIndex, stage in
                    FieldGuideStageDraft(
                        title: flattenedStageTitle(day: day, dayIndex: dayIndex, stop: stop, stopIndex: stopIndex, stage: stage),
                        goal: stage.goal,
                        sourceGeoAnchor: stop.geo?.sourceAnchor ?? "",
                        items: stage.items.enumerated().map { itemIndex, item in
                            FieldGuideItemDraft(
                                id: stableDraftID(dayIndex: dayIndex, stopIndex: stopIndex, stageIndex: stageIndex, itemIndex: itemIndex),
                                title: item.title,
                                guidance: item.guidance,
                                kind: FieldGuideItemKind(documentKind: item.itemKind),
                                priority: FieldGuidePriority(documentPriority: item.priority),
                                isBeforeLeaving: item.beforeLeaving || stage.kind == .beforeLeaving,
                                sourceLine: item.sourceLine,
                                isSynthetic: item.synthetic
                            )
                        }
                    )
                }
            }
        }

        return FieldGuideDraft(title: trip.title, storySummary: trip.summary, stages: stages)
    }

    private func flattenedStageTitle(day: ArcShootDayDocument, dayIndex: Int, stop: ArcStopDocument, stopIndex: Int, stage: ArcStageDocument) -> String {
        let totalStops = trip.days.reduce(0) { $0 + $1.stops.count }
        guard trip.days.count > 1 || totalStops > 1 else {
            return stage.title
        }

        let dayPrefix = trip.days.count > 1 ? "Day \(dayIndex + 1) · " : ""
        return "\(dayPrefix)Stop \(stopIndex + 1) · \(stop.title) — \(stage.title)"
    }

    private func stableDraftID(dayIndex: Int, stopIndex: Int, stageIndex: Int, itemIndex: Int) -> UUID {
        let uuidString = String(format: "00000000-0000-4000-8000-%012d", (dayIndex * 1_000_000) + (stopIndex * 10_000) + (stageIndex * 100) + itemIndex)
        return UUID(uuidString: uuidString) ?? UUID()
    }
}

nonisolated extension FieldGuideItemKind {
    init(documentKind: ArcCaptureItemKind) {
        switch documentKind {
        case .shot:
            self = .shot
        case .voice:
            self = .voice
        case .sound:
            self = .sound
        case .transition:
            self = .transition
        case .note:
            self = .note
        }
    }

    var documentKind: ArcCaptureItemKind {
        switch self {
        case .shot:
            return .shot
        case .voice:
            return .voice
        case .sound:
            return .sound
        case .transition:
            return .transition
        case .note:
            return .note
        }
    }
}

nonisolated extension FieldGuidePriority {
    init(documentPriority: ArcCapturePriority) {
        switch documentPriority {
        case .must:
            self = .must
        case .optional:
            self = .optional
        }
    }

    var documentPriority: ArcCapturePriority {
        switch self {
        case .must:
            return .must
        case .optional:
            return .optional
        }
    }
}

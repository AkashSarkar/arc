import Foundation

enum TripDocumentMapper {
    static func trip(from document: ArcPlanDocument, fallbackTitle: String? = nil) -> Trip {
        let title = clean(document.trip.title, fallback: fallbackTitle ?? "Imported Trip")
        let trip = Trip(
            title: title,
            summary: document.trip.summary,
            status: .active,
            outputIntent: OutputIntent(storedValue: document.trip.brief.outputIntent),
            captureMedium: CaptureMedium(rawValue: document.trip.brief.captureMedium) ?? .hybrid,
            targetPlatform: TargetPlatform(rawValue: document.trip.brief.targetPlatform) ?? .youtube,
            stylePreset: CaptureStylePreset(rawValue: document.trip.brief.stylePreset) ?? .natural
        )

        let sourceText = document.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceArtifactBody = sourceText.isEmpty ? document.trip.artifacts.first(where: { $0.kind == .shootList })?.body ?? "" : sourceText
        appendArtifact(
            TripArtifact(kind: .shootList, title: "Shoot List", body: sourceArtifactBody, source: .imported, orderIndex: 0, trip: trip),
            to: trip
        )

        for artifact in document.trip.artifacts where artifact.kind != .shootList {
            appendArtifact(
                TripArtifact(
                    kind: TripArtifactKind(documentKind: artifact.kind),
                    title: clean(artifact.title, fallback: artifact.kind.rawValue),
                    body: artifact.body,
                    source: .imported,
                    orderIndex: trip.artifacts.count,
                    trip: trip
                ),
                to: trip
            )
        }

        let sourceDays = document.trip.days.isEmpty ? [ArcShootDayDocument(title: "Day 1")] : document.trip.days
        for (dayIndex, dayDocument) in sourceDays.enumerated() {
            let day = ShootDay(
                orderIndex: dayIndex,
                date: date(from: dayDocument.date),
                title: clean(dayDocument.title, fallback: "Day \(dayIndex + 1)"),
                trip: trip
            )
            trip.days.append(day)

            let stops = dayDocument.stops.isEmpty ? [ArcStopDocument(title: title, placeName: title)] : dayDocument.stops
            for (stopIndex, stopDocument) in stops.enumerated() {
                let stopTitle = clean(stopDocument.title, fallback: "Stop \(stopIndex + 1)")
                let stop = Stop(
                    orderIndex: stopIndex,
                    title: stopTitle,
                    placeName: clean(stopDocument.placeName, fallback: stopTitle),
                    latitude: stopDocument.geo?.lat,
                    longitude: stopDocument.geo?.lon,
                    sourceGeoAnchor: stopDocument.geo?.sourceAnchor ?? "",
                    plannedArrival: date(from: stopDocument.plannedArrival),
                    plannedDeparture: date(from: stopDocument.plannedDeparture),
                    status: dayIndex == 0 && stopIndex == 0 ? .active : .upcoming,
                    day: day
                )
                day.stops.append(stop)

                let stages = stopDocument.stages.isEmpty ? fallbackStages(for: stopTitle) : stopDocument.stages
                for (stageIndex, stageDocument) in stages.enumerated() {
                    let stage = Stage(
                        orderIndex: stageIndex,
                        title: clean(stageDocument.title, fallback: "Stage \(stageIndex + 1)"),
                        goal: stageDocument.goal,
                        kind: StageKind(documentKind: stageDocument.kind),
                        stop: stop
                    )
                    stop.stages.append(stage)

                    for (itemIndex, itemDocument) in stageDocument.items.enumerated() {
                        let item = CaptureItem(
                            orderIndex: itemIndex,
                            title: clean(itemDocument.title, fallback: "Capture item \(itemIndex + 1)"),
                            guidance: itemDocument.guidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Capture this clearly enough to use in the edit." : itemDocument.guidance,
                            kind: FieldGuideItemKind(documentKind: itemDocument.itemKind),
                            priority: FieldGuidePriority(documentPriority: itemDocument.priority),
                            isBeforeLeaving: itemDocument.beforeLeaving || stage.kind == .beforeLeaving,
                            origin: itemDocument.synthetic ? .safetyNet : .planned,
                            sourceLine: itemDocument.sourceLine,
                            stage: stage
                        )
                        stage.items.append(item)
                    }
                }
            }
        }

        ensureTripHasContent(trip)
        return trip
    }

    static func planDocument(from trip: Trip, kind: ArcDocumentKind = .plan) -> ArcPlanDocument {
        ArcPlanDocument(
            kind: kind,
            generator: "Arc/1.0 (trip-v2)",
            sourceText: trip.sourceText,
            trip: ArcTripDocument(
                title: trip.title,
                summary: trip.summary,
                brief: ArcTripBriefDocument(
                    outputIntent: trip.outputIntent.rawValue,
                    captureMedium: trip.captureMedium.rawValue,
                    targetPlatform: trip.targetPlatform.rawValue,
                    stylePreset: trip.stylePreset.rawValue
                ),
                artifacts: trip.artifacts
                    .sorted { $0.orderIndex < $1.orderIndex }
                    .map { ArcTripArtifactDocument(kind: $0.kind.documentKind, title: $0.title, body: $0.body) },
                days: trip.orderedDays.map(dayDocument)
            ),
            execution: kind == .guide ? executionDocument(from: trip) : nil
        )
    }

    static func guideDocument(from trip: Trip) throws -> ArcGuideDocument {
        try ArcGuideDocument(document: planDocument(from: trip, kind: .guide))
    }

    static func markdownExport(for trip: Trip) -> String {
        var lines: [String] = []
        lines.append("# \(trip.title)")
        if !trip.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("")
            lines.append(trip.summary)
        }

        lines.append("")
        lines.append("## Coverage")
        lines.append("- Captured: \(trip.capturedCount)")
        lines.append("- Skipped: \(trip.skippedCount)")
        lines.append("- Missing: \(trip.missingCount)")
        lines.append("- Story safe: \(trip.isStorySafe ? "Yes" : "No")")

        for day in trip.orderedDays {
            lines.append("")
            lines.append("## \(day.title)")
            for stop in day.orderedStops {
                lines.append("")
                lines.append("### \(stop.title)")
                if !stop.sourceGeoAnchor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    lines.append(stop.sourceGeoAnchor)
                }
                for stage in stop.orderedStages {
                    lines.append("")
                    lines.append("#### \(stage.title)")
                    if !stage.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        lines.append("_\(stage.goal)_")
                    }
                    for item in stage.orderedItems {
                        let state = item.isCaptured ? "captured" : (item.isSkipped ? "skipped" : "open")
                        lines.append("- [\(state)] \(item.title) (\(item.kind.title), \(item.priority.title)): \(item.guidance)")
                        if !item.fieldNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            lines.append("  - Note: \(item.fieldNote)")
                        }
                    }
                }
            }
        }

        if let script = trip.artifacts.first(where: { $0.kind == .script }),
           !script.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("")
            lines.append("## Script")
            lines.append(script.body)
        }

        return lines.joined(separator: "\n")
    }

    static func generateScriptArtifact(for trip: Trip) -> TripArtifact {
        let body = scriptBody(for: trip)
        if let existing = trip.artifacts.first(where: { $0.kind == .script }) {
            existing.body = body
            existing.updatedAt = Date()
            existing.source = .generated
            return existing
        }

        let artifact = TripArtifact(
            kind: .script,
            title: "Editing Script",
            body: body,
            source: .generated,
            orderIndex: trip.artifacts.count,
            trip: trip
        )
        trip.artifacts.append(artifact)
        return artifact
    }

    private static func dayDocument(_ day: ShootDay) -> ArcShootDayDocument {
        ArcShootDayDocument(
            title: day.title,
            date: string(from: day.date),
            stops: day.orderedStops.map(stopDocument)
        )
    }

    private static func stopDocument(_ stop: Stop) -> ArcStopDocument {
        ArcStopDocument(
            title: stop.title,
            placeName: stop.placeName,
            geo: ArcGeoDocument(
                lat: stop.latitude,
                lon: stop.longitude,
                resolved: stop.hasResolvedCoordinate,
                sourceAnchor: stop.sourceGeoAnchor
            ),
            plannedArrival: string(from: stop.plannedArrival),
            plannedDeparture: string(from: stop.plannedDeparture),
            stages: stop.orderedStages.map(stageDocument)
        )
    }

    private static func stageDocument(_ stage: Stage) -> ArcStageDocument {
        ArcStageDocument(
            title: stage.title,
            goal: stage.goal,
            kind: stage.kind.documentKind,
            items: stage.orderedItems.map(itemDocument)
        )
    }

    private static func itemDocument(_ item: CaptureItem) -> ArcCaptureItemDocument {
        ArcCaptureItemDocument(
            title: item.title,
            guidance: item.guidance,
            itemKind: item.kind.documentKind,
            priority: item.priority.documentPriority,
            beforeLeaving: item.isBeforeLeaving,
            sourceLine: item.sourceLine,
            synthetic: item.origin == .safetyNet && item.sourceLine.isEmpty
        )
    }

    private static func executionDocument(from trip: Trip) -> ArcExecutionDocument {
        ArcExecutionDocument(
            executedAt: string(from: trip.completedAt ?? Date()) ?? "",
            stops: trip.orderedStops.map { stop in
                ArcExecutionStopDocument(
                    id: stop.id.uuidString,
                    arrivedAt: string(from: stop.arrivedAt),
                    departedAt: string(from: stop.departedAt),
                    items: stop.allItems.map { item in
                        ArcExecutionItemDocument(
                            id: item.id.uuidString,
                            captured: item.isCaptured,
                            capturedAt: string(from: item.capturedAt),
                            skipped: item.isSkipped,
                            origin: item.origin.rawValue
                        )
                    }
                )
            },
            coverage: ArcExecutionCoverageDocument(
                mustCaptured: trip.resolvedMustCount,
                total: trip.mustCount,
                storySafe: trip.isStorySafe
            )
        )
    }

    private static func appendArtifact(_ artifact: TripArtifact, to trip: Trip) {
        trip.artifacts.append(artifact)
    }

    private static func fallbackStages(for title: String) -> [ArcStageDocument] {
        [
            ArcStageDocument(
                title: "Start",
                goal: "Capture the \(title.lowercased()) beat clearly enough to carry the edit.",
                items: [
                    ArcCaptureItemDocument(
                        title: "Wide establishing frame",
                        guidance: "Hold long enough to locate the viewer.",
                        itemKind: .shot,
                        priority: .must,
                        sourceLine: "",
                        synthetic: true
                    )
                ]
            )
        ]
    }

    private static func ensureTripHasContent(_ trip: Trip) {
        guard trip.allItems.isEmpty else {
            return
        }

        let day = trip.orderedDays.first ?? ShootDay(orderIndex: 0, title: "Day 1", trip: trip)
        if trip.days.isEmpty {
            trip.days.append(day)
        }

        let stop = day.orderedStops.first ?? Stop(orderIndex: 0, title: trip.title, day: day)
        if day.stops.isEmpty {
            day.stops.append(stop)
        }

        let stage = stop.orderedStages.first ?? Stage(orderIndex: 0, title: "Start", goal: "Get the story started.", stop: stop)
        if stop.stages.isEmpty {
            stop.stages.append(stage)
        }

        stage.items.append(
            CaptureItem(
                orderIndex: 0,
                title: "Wide establishing frame",
                guidance: "Hold long enough to locate the viewer.",
                stage: stage
            )
        )
    }

    private static func scriptBody(for trip: Trip) -> String {
        var lines: [String] = []
        lines.append("# \(trip.title) Edit Outline")
        if !trip.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("")
            lines.append(trip.summary)
        }

        for stop in trip.orderedStops {
            lines.append("")
            lines.append("## \(stop.title)")

            let captured = stop.allItems.filter(\.isCaptured)
            let skipped = stop.allItems.filter(\.isSkipped)

            if captured.isEmpty {
                lines.append("- No captured items marked yet; review the footage manually.")
            } else {
                for item in captured {
                    lines.append("- \(item.kind.title): \(item.title) - \(item.guidance)")
                    if !item.fieldNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        lines.append("  - Field note: \(item.fieldNote)")
                    }
                }
            }

            if !skipped.isEmpty {
                lines.append("")
                lines.append("Skipped on purpose:")
                for item in skipped {
                    lines.append("- \(item.title)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func clean(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func date(from value: String?) -> Date? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return ISO8601DateFormatter.arc.date(from: value)
    }

    private static func string(from date: Date?) -> String? {
        guard let date else {
            return nil
        }

        return ISO8601DateFormatter.arc.string(from: date)
    }
}

private extension TripArtifactKind {
    init(documentKind: ArcTripArtifactKind) {
        switch documentKind {
        case .ideas:
            self = .ideas
        case .shootList:
            self = .shootList
        case .script:
            self = .script
        }
    }

    var documentKind: ArcTripArtifactKind {
        switch self {
        case .ideas:
            return .ideas
        case .shootList:
            return .shootList
        case .script:
            return .script
        }
    }
}

private extension StageKind {
    init(documentKind: ArcStageDocumentKind) {
        switch documentKind {
        case .standard:
            self = .standard
        case .beforeLeaving:
            self = .beforeLeaving
        case .safetyNet:
            self = .safetyNet
        }
    }

    var documentKind: ArcStageDocumentKind {
        switch self {
        case .standard:
            return .standard
        case .beforeLeaving:
            return .beforeLeaving
        case .safetyNet:
            return .safetyNet
        }
    }
}

private extension ISO8601DateFormatter {
    static let arc: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

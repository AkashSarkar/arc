import Foundation
import SwiftData

enum TripStatus: String, CaseIterable, Identifiable {
    case planning
    case active
    case completed
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .planning:
            return "Planning"
        case .active:
            return "Active"
        case .completed:
            return "Completed"
        case .archived:
            return "Archived"
        }
    }
}

enum TripArtifactKind: String, CaseIterable, Identifiable {
    case ideas
    case shootList
    case script

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ideas:
            return "Ideas"
        case .shootList:
            return "Shoot List"
        case .script:
            return "Script"
        }
    }
}

enum TripArtifactSource: String, CaseIterable, Identifiable {
    case pasted
    case imported
    case generated

    var id: String { rawValue }
}

enum StopStatus: String, CaseIterable, Identifiable {
    case upcoming
    case active
    case done
    case skipped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upcoming:
            return "Upcoming"
        case .active:
            return "Active"
        case .done:
            return "Done"
        case .skipped:
            return "Skipped"
        }
    }
}

enum StageKind: String, CaseIterable, Identifiable {
    case standard
    case beforeLeaving
    case safetyNet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "Stage"
        case .beforeLeaving:
            return "Before You Leave"
        case .safetyNet:
            return "Safety Net"
        }
    }
}

enum CaptureItemOrigin: String, CaseIterable, Identifiable {
    case planned
    case safetyNet
    case fieldAdded

    var id: String { rawValue }
}

@Model
final class Trip {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var title: String
    var summary: String
    var statusRawValue: String
    var outputIntentRawValue: String
    var captureMediumRawValue: String
    var targetPlatformRawValue: String
    var stylePresetRawValue: String
    var startDate: Date?
    var endDate: Date?
    var completedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \ShootDay.trip) var days: [ShootDay]
    @Relationship(deleteRule: .cascade, inverse: \TripArtifact.trip) var artifacts: [TripArtifact]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String,
        summary: String = "",
        status: TripStatus = .planning,
        outputIntent: OutputIntent = .fullTravelVlog,
        captureMedium: CaptureMedium = .hybrid,
        targetPlatform: TargetPlatform = .youtube,
        stylePreset: CaptureStylePreset = .natural,
        startDate: Date? = nil,
        endDate: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.summary = summary
        self.statusRawValue = status.rawValue
        self.outputIntentRawValue = outputIntent.rawValue
        self.captureMediumRawValue = captureMedium.rawValue
        self.targetPlatformRawValue = targetPlatform.rawValue
        self.stylePresetRawValue = stylePreset.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.completedAt = completedAt
        self.days = []
        self.artifacts = []
    }

    var status: TripStatus {
        get { TripStatus(rawValue: statusRawValue) ?? .planning }
        set { statusRawValue = newValue.rawValue }
    }

    var outputIntent: OutputIntent {
        get { OutputIntent(storedValue: outputIntentRawValue) }
        set { outputIntentRawValue = newValue.rawValue }
    }

    var captureMedium: CaptureMedium {
        get { CaptureMedium(rawValue: captureMediumRawValue) ?? outputIntent.defaultCaptureMedium }
        set { captureMediumRawValue = newValue.rawValue }
    }

    var targetPlatform: TargetPlatform {
        get { TargetPlatform(rawValue: targetPlatformRawValue) ?? outputIntent.defaultTargetPlatform }
        set { targetPlatformRawValue = newValue.rawValue }
    }

    var stylePreset: CaptureStylePreset {
        get { CaptureStylePreset(rawValue: stylePresetRawValue) ?? .natural }
        set { stylePresetRawValue = newValue.rawValue }
    }

    var orderedDays: [ShootDay] {
        days.sorted { $0.orderIndex < $1.orderIndex }
    }

    var orderedStops: [Stop] {
        orderedDays.flatMap(\.orderedStops)
    }

    var activeStop: Stop? {
        orderedStops.first { $0.status == .active }
            ?? orderedStops.first { $0.status == .upcoming }
            ?? orderedStops.first
    }

    var currentStage: Stage? {
        activeStop?.currentStage
    }

    var allStages: [Stage] {
        orderedStops.flatMap(\.orderedStages)
    }

    var allItems: [CaptureItem] {
        allStages.flatMap(\.orderedItems)
    }

    var capturedCount: Int {
        allItems.filter(\.isCaptured).count
    }

    var skippedCount: Int {
        allItems.filter(\.isSkipped).count
    }

    var resolvedCount: Int {
        allItems.filter(\.isResolved).count
    }

    var missingCount: Int {
        allItems.filter { !$0.isResolved }.count
    }

    var mustCount: Int {
        allItems.filter { $0.priority == .must || $0.isBeforeLeaving }.count
    }

    var resolvedMustCount: Int {
        allItems.filter { ($0.priority == .must || $0.isBeforeLeaving) && $0.isResolved }.count
    }

    var isStorySafe: Bool {
        mustCount > 0 && mustCount == resolvedMustCount
    }

    var sourceText: String {
        artifacts.first { $0.kind == .shootList }?.body ?? ""
    }
}

@Model
final class TripArtifact {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var title: String
    var body: String
    var sourceRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var orderIndex: Int
    var trip: Trip?

    init(
        id: UUID = UUID(),
        kind: TripArtifactKind,
        title: String,
        body: String = "",
        source: TripArtifactSource = .pasted,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        orderIndex: Int,
        trip: Trip? = nil
    ) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.title = title
        self.body = body
        self.sourceRawValue = source.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.orderIndex = orderIndex
        self.trip = trip
    }

    var kind: TripArtifactKind {
        get { TripArtifactKind(rawValue: kindRawValue) ?? .shootList }
        set { kindRawValue = newValue.rawValue }
    }

    var source: TripArtifactSource {
        get { TripArtifactSource(rawValue: sourceRawValue) ?? .pasted }
        set { sourceRawValue = newValue.rawValue }
    }
}

@Model
final class ShootDay {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var date: Date?
    var title: String
    var notes: String
    var windowModeRawValue: String
    var startTime: Date?
    var endTime: Date?
    var currentStopOrderIndex: Int
    var trip: Trip?
    @Relationship(deleteRule: .cascade, inverse: \Stop.day) var stops: [Stop]

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        date: Date? = nil,
        title: String,
        notes: String = "",
        windowMode: ShootWindowMode = .now,
        startTime: Date? = nil,
        endTime: Date? = nil,
        currentStopOrderIndex: Int = 0,
        trip: Trip? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.date = date
        self.title = title
        self.notes = notes
        self.windowModeRawValue = windowMode.rawValue
        self.startTime = startTime
        self.endTime = endTime
        self.currentStopOrderIndex = currentStopOrderIndex
        self.trip = trip
        self.stops = []
    }

    var windowMode: ShootWindowMode {
        get { ShootWindowMode(rawValue: windowModeRawValue) ?? .now }
        set { windowModeRawValue = newValue.rawValue }
    }

    var orderedStops: [Stop] {
        stops.sorted { $0.orderIndex < $1.orderIndex }
    }
}

@Model
final class Stop {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var title: String
    var placeName: String
    var latitude: Double?
    var longitude: Double?
    var sourceGeoAnchor: String
    var plannedArrival: Date?
    var plannedDeparture: Date?
    var enrichmentJSON: String
    var lastEnrichedAt: Date?
    var statusRawValue: String
    var arrivedAt: Date?
    var departedAt: Date?
    var currentStageOrderIndex: Int
    var day: ShootDay?
    @Relationship(deleteRule: .cascade, inverse: \Stage.stop) var stages: [Stage]

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        title: String,
        placeName: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        sourceGeoAnchor: String = "",
        plannedArrival: Date? = nil,
        plannedDeparture: Date? = nil,
        enrichmentJSON: String = "",
        lastEnrichedAt: Date? = nil,
        status: StopStatus = .upcoming,
        arrivedAt: Date? = nil,
        departedAt: Date? = nil,
        currentStageOrderIndex: Int = 0,
        day: ShootDay? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.title = title
        self.placeName = placeName.isEmpty ? title : placeName
        self.latitude = latitude
        self.longitude = longitude
        self.sourceGeoAnchor = sourceGeoAnchor
        self.plannedArrival = plannedArrival
        self.plannedDeparture = plannedDeparture
        self.enrichmentJSON = enrichmentJSON
        self.lastEnrichedAt = lastEnrichedAt
        self.statusRawValue = status.rawValue
        self.arrivedAt = arrivedAt
        self.departedAt = departedAt
        self.currentStageOrderIndex = currentStageOrderIndex
        self.day = day
        self.stages = []
    }

    var name: String {
        get { title }
        set {
            title = newValue
            if placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                placeName = newValue
            }
        }
    }

    var status: StopStatus {
        get { StopStatus(rawValue: statusRawValue) ?? .upcoming }
        set { statusRawValue = newValue.rawValue }
    }

    var orderedStages: [Stage] {
        stages.sorted { $0.orderIndex < $1.orderIndex }
    }

    var currentStage: Stage? {
        let stages = orderedStages
        guard !stages.isEmpty else {
            return nil
        }

        return stages.first { $0.orderIndex == currentStageOrderIndex } ?? stages.first
    }

    var hasResolvedCoordinate: Bool {
        latitude != nil && longitude != nil
    }

    var coordinateSummary: String {
        guard let latitude, let longitude else {
            return "Needs location"
        }

        return "\(latitude.formatted(.number.precision(.fractionLength(5)))), \(longitude.formatted(.number.precision(.fractionLength(5))))"
    }

    var allItems: [CaptureItem] {
        orderedStages.flatMap(\.orderedItems)
    }

    var isStorySafe: Bool {
        let musts = allItems.filter { $0.priority == .must || $0.isBeforeLeaving }
        return !musts.isEmpty && musts.allSatisfy(\.isResolved)
    }
}

@Model
final class Stage {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var title: String
    var goal: String
    var kindRawValue: String
    var stop: Stop?
    @Relationship(deleteRule: .cascade, inverse: \CaptureItem.stage) var items: [CaptureItem]

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        title: String,
        goal: String = "",
        kind: StageKind = .standard,
        stop: Stop? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.title = title
        self.goal = goal
        self.kindRawValue = kind.rawValue
        self.stop = stop
        self.items = []
    }

    var kind: StageKind {
        get { StageKind(rawValue: kindRawValue) ?? .standard }
        set { kindRawValue = newValue.rawValue }
    }

    var orderedItems: [CaptureItem] {
        items.sorted { $0.orderIndex < $1.orderIndex }
    }

    var capturedCount: Int {
        items.filter(\.isCaptured).count
    }

    var skippedCount: Int {
        items.filter(\.isSkipped).count
    }

    var resolvedCount: Int {
        items.filter(\.isResolved).count
    }

    var missingItems: [CaptureItem] {
        orderedItems.filter { !$0.isResolved }
    }

    var mustItems: [CaptureItem] {
        orderedItems.filter { $0.priority == .must || $0.isBeforeLeaving }
    }

    var unresolvedMustItems: [CaptureItem] {
        mustItems.filter { !$0.isResolved }
    }

    var isStorySafe: Bool {
        !mustItems.isEmpty && unresolvedMustItems.isEmpty
    }

    var mantra: String {
        let cleanGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = cleanGoal.isEmpty ? title : cleanGoal
        let count = unresolvedMustItems.count
        return count == 0 ? "\(base) - musts done." : "\(base) - \(count) musts left."
    }

    var progress: Double {
        guard !items.isEmpty else {
            return 0
        }

        return Double(resolvedCount) / Double(items.count)
    }
}

@Model
final class CaptureItem {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var title: String
    var guidance: String
    var kindRawValue: String
    var priorityRawValue: String
    var isBeforeLeaving: Bool
    var isCaptured: Bool
    var isSkipped: Bool
    var fieldNote: String
    @Attribute(.externalStorage) var capturedPhotoData: Data?
    var capturedPhotoAttachedAt: Date?
    var capturedAt: Date?
    var skippedAt: Date?
    var originRawValue: String
    var sourceLine: String
    var stage: Stage?

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        title: String,
        guidance: String = "",
        kind: FieldGuideItemKind = .shot,
        priority: FieldGuidePriority = .must,
        isBeforeLeaving: Bool = false,
        isCaptured: Bool = false,
        isSkipped: Bool = false,
        fieldNote: String = "",
        capturedPhotoData: Data? = nil,
        capturedPhotoAttachedAt: Date? = nil,
        capturedAt: Date? = nil,
        skippedAt: Date? = nil,
        origin: CaptureItemOrigin = .planned,
        sourceLine: String = "",
        stage: Stage? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.title = title
        self.guidance = guidance
        self.kindRawValue = kind.rawValue
        self.priorityRawValue = priority.rawValue
        self.isBeforeLeaving = isBeforeLeaving
        self.isCaptured = isCaptured
        self.isSkipped = isSkipped
        self.fieldNote = fieldNote
        self.capturedPhotoData = capturedPhotoData
        self.capturedPhotoAttachedAt = capturedPhotoAttachedAt
        self.capturedAt = capturedAt
        self.skippedAt = skippedAt
        self.originRawValue = origin.rawValue
        self.sourceLine = sourceLine
        self.stage = stage
    }

    var kind: FieldGuideItemKind {
        get { FieldGuideItemKind(rawValue: kindRawValue) ?? .shot }
        set { kindRawValue = newValue.rawValue }
    }

    var priority: FieldGuidePriority {
        get { FieldGuidePriority(rawValue: priorityRawValue) ?? .must }
        set { priorityRawValue = newValue.rawValue }
    }

    var origin: CaptureItemOrigin {
        get { CaptureItemOrigin(rawValue: originRawValue) ?? .planned }
        set { originRawValue = newValue.rawValue }
    }

    var displayRoleTitle: String {
        if origin == .safetyNet {
            return "Safety Net"
        }

        return kind.title
    }

    var isResolved: Bool {
        isCaptured || isSkipped
    }
}

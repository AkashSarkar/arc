import Foundation
import SwiftData

@Model
final class ShootPlan {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var notes: String
    var rawResponse: String
    var sourceRawValue: String?
    var importedPlanText: String = ""
    var storySummary: String = ""
    var currentStageOrderIndex: Int = 0
    var outputIntentRawValue: String
    var captureMediumRawValue: String?
    var targetPlatformRawValue: String?
    var stylePresetRawValue: String?
    var shootWindowModeRawValue: String
    var shootWindowSummary: String
    var shootDate: Date
    var shootStartTime: Date
    var shootEndTime: Date
    var isApprovedForField: Bool
    var approvedAt: Date?
    var completedAt: Date?
    var location: ShootLocation?
    @Relationship(deleteRule: .cascade, inverse: \ShootPlanItem.plan) var items: [ShootPlanItem]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        notes: String = "",
        rawResponse: String = "",
        source: CapturePlanSource = .locationGenerated,
        importedPlanText: String = "",
        storySummary: String = "",
        currentStageOrderIndex: Int = 0,
        outputIntent: OutputIntent = .instagramCarousel,
        captureMedium: CaptureMedium = .photo,
        targetPlatform: TargetPlatform = .instagram,
        stylePreset: CaptureStylePreset = .natural,
        shootWindowMode: ShootWindowMode = .now,
        shootWindowSummary: String = "Use current conditions.",
        shootDate: Date = Date(),
        shootStartTime: Date = Date(),
        shootEndTime: Date = Date(),
        isApprovedForField: Bool = false,
        approvedAt: Date? = nil,
        completedAt: Date? = nil,
        location: ShootLocation? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.notes = notes
        self.rawResponse = rawResponse
        self.sourceRawValue = source.rawValue
        self.importedPlanText = importedPlanText
        self.storySummary = storySummary
        self.currentStageOrderIndex = currentStageOrderIndex
        self.outputIntentRawValue = outputIntent.rawValue
        self.captureMediumRawValue = captureMedium.rawValue
        self.targetPlatformRawValue = targetPlatform.rawValue
        self.stylePresetRawValue = stylePreset.rawValue
        self.shootWindowModeRawValue = shootWindowMode.rawValue
        self.shootWindowSummary = shootWindowSummary
        self.shootDate = shootDate
        self.shootStartTime = shootStartTime
        self.shootEndTime = shootEndTime
        self.isApprovedForField = isApprovedForField
        self.approvedAt = approvedAt
        self.completedAt = completedAt
        self.location = location
        self.items = []
    }

    var source: CapturePlanSource {
        CapturePlanSource(rawValue: sourceRawValue ?? "") ?? .locationGenerated
    }

    var outputIntent: OutputIntent {
        OutputIntent(storedValue: outputIntentRawValue)
    }

    var captureMedium: CaptureMedium {
        CaptureMedium(rawValue: captureMediumRawValue ?? "") ?? outputIntent.defaultCaptureMedium
    }

    var targetPlatform: TargetPlatform {
        TargetPlatform(rawValue: targetPlatformRawValue ?? "") ?? outputIntent.defaultTargetPlatform
    }

    var stylePreset: CaptureStylePreset {
        CaptureStylePreset(rawValue: stylePresetRawValue ?? "") ?? .natural
    }

    var shootWindowMode: ShootWindowMode {
        ShootWindowMode(rawValue: shootWindowModeRawValue) ?? .now
    }

    var orderedItems: [ShootPlanItem] {
        items.sorted { $0.orderIndex < $1.orderIndex }
    }

    var fieldStages: [FieldGuideStage] {
        Dictionary(grouping: orderedItems) { item in
            FieldGuideStageKey(
                orderIndex: item.resolvedStageOrderIndex,
                title: item.resolvedStageTitle
            )
        }
        .map { key, items in
            let sortedItems = items.sorted { $0.orderIndex < $1.orderIndex }
            return FieldGuideStage(
                orderIndex: key.orderIndex,
                title: key.title,
                goal: sortedItems.first(where: { !$0.resolvedStageGoal.isEmpty })?.resolvedStageGoal ?? "",
                items: sortedItems
            )
        }
        .sorted { $0.orderIndex < $1.orderIndex }
    }

    var currentStage: FieldGuideStage? {
        let stages = fieldStages
        guard !stages.isEmpty else {
            return nil
        }

        if let stage = stages.first(where: { $0.orderIndex == currentStageOrderIndex }) {
            return stage
        }

        return stages.first
    }

    var capturedCount: Int {
        items.filter { $0.isCaptured }.count
    }

    var skippedCount: Int {
        items.filter { $0.isSkipped }.count
    }

    var resolvedCount: Int {
        items.filter { $0.isResolved }.count
    }

    var missingCount: Int {
        items.filter { !$0.isResolved }.count
    }

    var completionProgress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(capturedCount) / Double(items.count)
    }

    var fieldCompletionProgress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(resolvedCount) / Double(items.count)
    }
}

@Model
final class ShootPlanItem {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var title: String
    var role: String
    var guidance: String
    var isCaptured: Bool
    var stageTitle: String = "Shot List"
    var stageOrderIndex: Int = 0
    var stageGoal: String = ""
    var kindRawValue: String?
    var priorityRawValue: String?
    var isBeforeLeaving: Bool = false
    var isSkipped: Bool = false
    var fieldNote: String = ""
    @Attribute(.externalStorage) var capturedPhotoData: Data?
    var capturedPhotoAttachedAt: Date?
    var plan: ShootPlan?

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        title: String,
        role: String,
        guidance: String,
        isCaptured: Bool = false,
        stageTitle: String = "Shot List",
        stageOrderIndex: Int = 0,
        stageGoal: String = "",
        kind: FieldGuideItemKind = .shot,
        priority: FieldGuidePriority = .must,
        isBeforeLeaving: Bool = false,
        isSkipped: Bool = false,
        fieldNote: String = "",
        capturedPhotoData: Data? = nil,
        capturedPhotoAttachedAt: Date? = nil,
        plan: ShootPlan? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.title = title
        self.role = role
        self.guidance = guidance
        self.isCaptured = isCaptured
        self.stageTitle = stageTitle
        self.stageOrderIndex = stageOrderIndex
        self.stageGoal = stageGoal
        self.kindRawValue = kind.rawValue
        self.priorityRawValue = priority.rawValue
        self.isBeforeLeaving = isBeforeLeaving
        self.isSkipped = isSkipped
        self.fieldNote = fieldNote
        self.capturedPhotoData = capturedPhotoData
        self.capturedPhotoAttachedAt = capturedPhotoAttachedAt
        self.plan = plan
    }

    var kind: FieldGuideItemKind {
        FieldGuideItemKind(rawValue: kindRawValue ?? "") ?? .shot
    }

    var priority: FieldGuidePriority {
        FieldGuidePriority(rawValue: priorityRawValue ?? "") ?? .must
    }

    var displayRoleTitle: String {
        let trimmedRole = role.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRole.isEmpty, trimmedRole.caseInsensitiveCompare(kind.title) != .orderedSame else {
            return kind.title
        }

        return trimmedRole
    }

    var isResolved: Bool {
        isCaptured || isSkipped
    }

    var resolvedStageTitle: String {
        let trimmedTitle = stageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Shot List" : trimmedTitle
    }

    var resolvedStageOrderIndex: Int {
        max(stageOrderIndex, 0)
    }

    var resolvedStageGoal: String {
        stageGoal.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

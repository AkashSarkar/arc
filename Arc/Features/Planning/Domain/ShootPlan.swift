import Foundation
import SwiftData

@Model
final class ShootPlan {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var notes: String
    var rawResponse: String
    var outputIntentRawValue: String
    var shootWindowModeRawValue: String
    var shootWindowSummary: String
    var shootDate: Date
    var shootStartTime: Date
    var shootEndTime: Date
    var isApprovedForField: Bool
    var approvedAt: Date?
    var location: ShootLocation?
    @Relationship(deleteRule: .cascade, inverse: \ShootPlanItem.plan) var items: [ShootPlanItem]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        notes: String = "",
        rawResponse: String = "",
        outputIntent: OutputIntent = .instagramCarousel,
        shootWindowMode: ShootWindowMode = .now,
        shootWindowSummary: String = "Use current conditions.",
        shootDate: Date = Date(),
        shootStartTime: Date = Date(),
        shootEndTime: Date = Date(),
        isApprovedForField: Bool = false,
        approvedAt: Date? = nil,
        location: ShootLocation? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.notes = notes
        self.rawResponse = rawResponse
        self.outputIntentRawValue = outputIntent.rawValue
        self.shootWindowModeRawValue = shootWindowMode.rawValue
        self.shootWindowSummary = shootWindowSummary
        self.shootDate = shootDate
        self.shootStartTime = shootStartTime
        self.shootEndTime = shootEndTime
        self.isApprovedForField = isApprovedForField
        self.approvedAt = approvedAt
        self.location = location
        self.items = []
    }

    var outputIntent: OutputIntent {
        OutputIntent(rawValue: outputIntentRawValue) ?? .instagramCarousel
    }

    var shootWindowMode: ShootWindowMode {
        ShootWindowMode(rawValue: shootWindowModeRawValue) ?? .now
    }

    var orderedItems: [ShootPlanItem] {
        items.sorted { $0.orderIndex < $1.orderIndex }
    }

    var capturedCount: Int {
        items.filter { $0.isCaptured }.count
    }

    var missingCount: Int {
        max(items.count - capturedCount, 0)
    }

    var completionProgress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(capturedCount) / Double(items.count)
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
    var plan: ShootPlan?

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        title: String,
        role: String,
        guidance: String,
        isCaptured: Bool = false,
        plan: ShootPlan? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.title = title
        self.role = role
        self.guidance = guidance
        self.isCaptured = isCaptured
        self.plan = plan
    }
}

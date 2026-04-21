import Foundation
import SwiftData

@Model
final class ShootLocation {
    @Attribute(.unique) var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var createdAt: Date
    var enrichmentJSON: String
    var lastEnrichedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \ShootPlan.location) var plan: ShootPlan?

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        createdAt: Date = Date(),
        enrichmentJSON: String = "",
        lastEnrichedAt: Date? = nil,
        plan: ShootPlan? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
        self.enrichmentJSON = enrichmentJSON
        self.lastEnrichedAt = lastEnrichedAt
        self.plan = plan
    }
}

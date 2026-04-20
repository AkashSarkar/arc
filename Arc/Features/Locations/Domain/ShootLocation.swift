import Foundation
import SwiftData

@Model
final class ShootLocation {
    @Attribute(.unique) var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ShootPlan.location) var plan: ShootPlan?

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        createdAt: Date = Date(),
        plan: ShootPlan? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
        self.plan = plan
    }
}

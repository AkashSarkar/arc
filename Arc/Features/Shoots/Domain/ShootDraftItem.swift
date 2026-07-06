import Foundation

struct ShootDraftItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var role: String
    var guidance: String

    init(
        id: UUID = UUID(),
        title: String,
        role: String,
        guidance: String
    ) {
        self.id = id
        self.title = title
        self.role = role
        self.guidance = guidance
    }

    init(draft: PlannedShotDraft) {
        self.init(title: draft.title, role: draft.role, guidance: draft.guidance)
    }

    var plannedShotDraft: PlannedShotDraft {
        PlannedShotDraft(title: title, role: role, guidance: guidance)
    }
}

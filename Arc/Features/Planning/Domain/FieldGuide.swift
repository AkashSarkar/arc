import Foundation

nonisolated enum CapturePlanSource: String, CaseIterable, Identifiable {
    case locationGenerated
    case importedText

    var id: String { rawValue }

    var title: String {
        switch self {
        case .locationGenerated:
            return "Location Generated"
        case .importedText:
            return "Imported Plan"
        }
    }
}

nonisolated enum FieldGuideItemKind: String, CaseIterable, Identifiable {
    case shot
    case voice
    case sound
    case transition
    case note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shot:
            return "Shot"
        case .voice:
            return "Voice"
        case .sound:
            return "Sound"
        case .transition:
            return "Transition"
        case .note:
            return "Note"
        }
    }

    var systemImage: String {
        switch self {
        case .shot:
            return "camera.viewfinder"
        case .voice:
            return "waveform"
        case .sound:
            return "ear"
        case .transition:
            return "arrow.triangle.swap"
        case .note:
            return "note.text"
        }
    }
}

nonisolated enum FieldGuidePriority: String, CaseIterable, Identifiable {
    case must
    case optional

    var id: String { rawValue }

    var title: String {
        switch self {
        case .must:
            return "Must"
        case .optional:
            return "Optional"
        }
    }
}

nonisolated struct FieldGuideDraft: Equatable {
    var title: String
    var storySummary: String
    var stages: [FieldGuideStageDraft]

    static let empty = FieldGuideDraft(title: "", storySummary: "", stages: [])

    var itemCount: Int {
        stages.reduce(0) { $0 + $1.items.count }
    }
}

nonisolated struct FieldGuideStageDraft: Identifiable, Equatable {
    let id: UUID
    var title: String
    var goal: String
    var sourceGeoAnchor: String
    var items: [FieldGuideItemDraft]

    init(
        id: UUID = UUID(),
        title: String,
        goal: String = "",
        sourceGeoAnchor: String = "",
        items: [FieldGuideItemDraft] = []
    ) {
        self.id = id
        self.title = title
        self.goal = goal
        self.sourceGeoAnchor = sourceGeoAnchor
        self.items = items
    }
}

nonisolated struct FieldGuideItemDraft: Identifiable, Equatable {
    let id: UUID
    var title: String
    var guidance: String
    var kind: FieldGuideItemKind
    var priority: FieldGuidePriority
    var isBeforeLeaving: Bool
    var sourceLine: String
    var isSynthetic: Bool

    init(
        id: UUID = UUID(),
        title: String,
        guidance: String = "",
        kind: FieldGuideItemKind = .shot,
        priority: FieldGuidePriority = .must,
        isBeforeLeaving: Bool = false,
        sourceLine: String = "",
        isSynthetic: Bool = false
    ) {
        self.id = id
        self.title = title
        self.guidance = guidance
        self.kind = kind
        self.priority = priority
        self.isBeforeLeaving = isBeforeLeaving
        self.sourceLine = sourceLine
        self.isSynthetic = isSynthetic
    }
}

nonisolated struct FieldGuideStageKey: Hashable {
    let orderIndex: Int
    let title: String
}

nonisolated struct FieldGuideStage: Identifiable {
    let orderIndex: Int
    let title: String
    let goal: String
    let items: [ShootPlanItem]

    var id: Int { orderIndex }

    var capturedCount: Int {
        items.filter(\.isCaptured).count
    }

    var skippedCount: Int {
        items.filter(\.isSkipped).count
    }

    var resolvedCount: Int {
        items.filter(\.isResolved).count
    }

    var missingItems: [ShootPlanItem] {
        items.filter { !$0.isResolved }
    }

    var progress: Double {
        guard !items.isEmpty else {
            return 0
        }

        return Double(resolvedCount) / Double(items.count)
    }
}

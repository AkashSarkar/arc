import Foundation
import UniformTypeIdentifiers

nonisolated enum ArcDocumentKind: String, Codable, Equatable {
    case plan
    case guide
}

nonisolated enum ArcStageDocumentKind: String, Codable, Equatable {
    case standard
    case beforeLeaving
    case safetyNet
}

nonisolated enum ArcTripArtifactKind: String, Codable, Equatable {
    case ideas
    case shootList
    case script
}

nonisolated enum ArcCaptureItemKind: String, Codable, Equatable {
    case shot
    case voice
    case sound
    case transition
    case note
}

nonisolated enum ArcCapturePriority: String, Codable, Equatable {
    case must
    case optional
}

nonisolated struct ArcPlanDocument: Codable, Equatable {
    static let formatIdentifier = "arc.guide"
    static let currentSchemaVersion = 1

    var format: String
    var schemaVersion: Int
    var kind: ArcDocumentKind
    var generator: String
    var sourceText: String
    var unparsedRemainder: [String]
    var trip: ArcTripDocument
    var execution: ArcExecutionDocument?

    init(
        format: String = Self.formatIdentifier,
        schemaVersion: Int = Self.currentSchemaVersion,
        kind: ArcDocumentKind = .plan,
        generator: String,
        sourceText: String = "",
        unparsedRemainder: [String] = [],
        trip: ArcTripDocument,
        execution: ArcExecutionDocument? = nil
    ) {
        self.format = format
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.generator = generator
        self.sourceText = sourceText
        self.unparsedRemainder = unparsedRemainder
        self.trip = trip
        self.execution = execution
    }
}

nonisolated struct ArcGuideDocument: Codable, Equatable {
    var document: ArcPlanDocument

    init(document: ArcPlanDocument) throws {
        guard document.kind == .guide else {
            throw ArcDocumentError.kindMismatch(expected: .guide, actual: document.kind)
        }

        self.document = document
    }

    init(from decoder: Decoder) throws {
        let document = try ArcPlanDocument(from: decoder)
        try self.init(document: document)
    }

    func encode(to encoder: Encoder) throws {
        try document.encode(to: encoder)
    }
}

nonisolated struct ArcTripDocument: Codable, Equatable {
    var title: String
    var summary: String
    var brief: ArcTripBriefDocument
    var artifacts: [ArcTripArtifactDocument]
    var days: [ArcShootDayDocument]

    init(
        title: String,
        summary: String = "",
        brief: ArcTripBriefDocument = .empty,
        artifacts: [ArcTripArtifactDocument] = [],
        days: [ArcShootDayDocument] = []
    ) {
        self.title = title
        self.summary = summary
        self.brief = brief
        self.artifacts = artifacts
        self.days = days
    }
}

nonisolated struct ArcTripBriefDocument: Codable, Equatable {
    static let empty = ArcTripBriefDocument(
        outputIntent: "",
        captureMedium: "",
        targetPlatform: "",
        stylePreset: ""
    )

    var outputIntent: String
    var captureMedium: String
    var targetPlatform: String
    var stylePreset: String
}

nonisolated struct ArcTripArtifactDocument: Codable, Equatable {
    var kind: ArcTripArtifactKind
    var title: String
    var body: String
}

nonisolated struct ArcShootDayDocument: Codable, Equatable {
    var title: String
    var date: String?
    var stops: [ArcStopDocument]

    init(title: String, date: String? = nil, stops: [ArcStopDocument] = []) {
        self.title = title
        self.date = date
        self.stops = stops
    }
}

nonisolated struct ArcStopDocument: Codable, Equatable {
    var title: String
    var placeName: String
    var geo: ArcGeoDocument?
    var plannedArrival: String?
    var plannedDeparture: String?
    var stages: [ArcStageDocument]

    init(
        title: String,
        placeName: String = "",
        geo: ArcGeoDocument? = nil,
        plannedArrival: String? = nil,
        plannedDeparture: String? = nil,
        stages: [ArcStageDocument] = []
    ) {
        self.title = title
        self.placeName = placeName
        self.geo = geo
        self.plannedArrival = plannedArrival
        self.plannedDeparture = plannedDeparture
        self.stages = stages
    }
}

nonisolated struct ArcGeoDocument: Codable, Equatable {
    var lat: Double?
    var lon: Double?
    var resolved: Bool
    var sourceAnchor: String

    init(lat: Double? = nil, lon: Double? = nil, resolved: Bool = false, sourceAnchor: String = "") {
        self.lat = lat
        self.lon = lon
        self.resolved = resolved
        self.sourceAnchor = sourceAnchor
    }
}

nonisolated struct ArcStageDocument: Codable, Equatable {
    var title: String
    var goal: String
    var kind: ArcStageDocumentKind
    var items: [ArcCaptureItemDocument]

    init(
        title: String,
        goal: String = "",
        kind: ArcStageDocumentKind = .standard,
        items: [ArcCaptureItemDocument] = []
    ) {
        self.title = title
        self.goal = goal
        self.kind = kind
        self.items = items
    }
}

nonisolated struct ArcCaptureItemDocument: Codable, Equatable {
    var title: String
    var guidance: String
    var itemKind: ArcCaptureItemKind
    var priority: ArcCapturePriority
    var beforeLeaving: Bool
    var sourceLine: String
    var synthetic: Bool

    init(
        title: String,
        guidance: String = "",
        itemKind: ArcCaptureItemKind = .shot,
        priority: ArcCapturePriority = .must,
        beforeLeaving: Bool = false,
        sourceLine: String = "",
        synthetic: Bool = false
    ) {
        self.title = title
        self.guidance = guidance
        self.itemKind = itemKind
        self.priority = priority
        self.beforeLeaving = beforeLeaving
        self.sourceLine = sourceLine
        self.synthetic = synthetic
    }
}

nonisolated struct ArcExecutionDocument: Codable, Equatable {
    var executedAt: String
    var stops: [ArcExecutionStopDocument]
    var coverage: ArcExecutionCoverageDocument
}

nonisolated struct ArcExecutionStopDocument: Codable, Equatable {
    var id: String
    var arrivedAt: String?
    var departedAt: String?
    var items: [ArcExecutionItemDocument]
}

nonisolated struct ArcExecutionItemDocument: Codable, Equatable {
    var id: String
    var captured: Bool
    var capturedAt: String?
    var skipped: Bool
    var origin: String
}

nonisolated struct ArcExecutionCoverageDocument: Codable, Equatable {
    var mustCaptured: Int
    var total: Int
    var storySafe: Bool
}

nonisolated enum ArcDocumentError: LocalizedError, Equatable {
    case invalidFormat(String)
    case unsupportedSchemaVersion(Int)
    case invalidPlan(String)
    case kindMismatch(expected: ArcDocumentKind, actual: ArcDocumentKind)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "This is not an Arc guide document."
        case .unsupportedSchemaVersion:
            return "This document was made by a newer version of Arc."
        case .invalidPlan(let reason):
            return reason
        case .kindMismatch(let expected, let actual):
            return "Expected \(expected.rawValue), but found \(actual.rawValue)."
        }
    }
}

nonisolated enum ArcDocumentCodec {
    static func encode(_ document: ArcPlanDocument) throws -> Data {
        try validate(document)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }

    static func decodePlan(from data: Data) throws -> ArcPlanDocument {
        let decoder = JSONDecoder()
        let document = try decoder.decode(ArcPlanDocument.self, from: data)
        try validate(document)
        guard document.kind == .plan else {
            throw ArcDocumentError.kindMismatch(expected: .plan, actual: document.kind)
        }

        return document
    }

    static func decodePlanOrGuide(from data: Data) throws -> ArcPlanDocument {
        let decoder = JSONDecoder()
        let document = try decoder.decode(ArcPlanDocument.self, from: data)
        try validate(document)
        guard document.kind == .plan || document.kind == .guide else {
            throw ArcDocumentError.invalidPlan("Unsupported Arc document kind.")
        }

        return document
    }

    static func decodeGuide(from data: Data) throws -> ArcGuideDocument {
        let decoder = JSONDecoder()
        let document = try decoder.decode(ArcPlanDocument.self, from: data)
        try validate(document)
        return try ArcGuideDocument(document: document)
    }

    static func validate(_ document: ArcPlanDocument) throws {
        guard document.format == ArcPlanDocument.formatIdentifier else {
            throw ArcDocumentError.invalidFormat(document.format)
        }

        guard document.schemaVersion <= ArcPlanDocument.currentSchemaVersion else {
            throw ArcDocumentError.unsupportedSchemaVersion(document.schemaVersion)
        }

        guard !document.trip.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ArcDocumentError.invalidPlan("Trip title is required.")
        }

        guard !document.trip.days.isEmpty else {
            throw ArcDocumentError.invalidPlan("At least one day is required.")
        }
    }
}

extension UTType {
    static let arcGuide = UTType(exportedAs: "com.arc.guide")
}

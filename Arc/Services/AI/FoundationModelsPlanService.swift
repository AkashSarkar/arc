import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class FoundationModelsPlanService {
    enum ParseOutcome {
        case unavailable(String?)
        case parsed(ArcPlanDocument)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private var session: LanguageModelSession?
    #endif

    func prewarm() {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            return
        }

        guard case .available = SystemLanguageModel.default.availability else {
            return
        }

        let session = existingOrNewSession()
        session.prewarm()
        #endif
    }

    func parse(title: String, text: String, fallback: ArcPlanDocument) async -> ParseOutcome {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            return .unavailable(nil)
        }

        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable("Turn on Apple Intelligence for smarter imports.")
        case .unavailable(.modelNotReady):
            return .unavailable("Smart parsing is downloading — using basic parsing for now.")
        case .unavailable(.deviceNotEligible):
            return .unavailable(nil)
        @unknown default:
            return .unavailable(nil)
        }

        do {
            let generated = try await existingOrNewSession()
                .respond(to: prompt(title: title, text: text), generating: GeneratedPlan.self)
                .content
            return .parsed(generated.document(title: title, sourceText: text))
        } catch LanguageModelSession.GenerationError.guardrailViolation(_) {
            return .parsed(fallback)
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize(_) {
            return await parseByDayChunks(title: title, text: text, fallback: fallback)
        } catch {
            return .unavailable(nil)
        }
        #else
        return .unavailable(nil)
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func parseByDayChunks(title: String, text: String, fallback: ArcPlanDocument) async -> ParseOutcome {
        let chunks = ImportedPlanParser.dayChunks(title: title, text: text)
        guard chunks.count > 1 else {
            return .parsed(fallback)
        }

        var parsedDays: [ArcShootDayDocument] = []
        for chunk in chunks {
            let chunkFallback = ImportedPlanParser.parseDocument(title: chunk.title, text: chunk.text)
            do {
                let generated = try await existingOrNewSession()
                    .respond(to: prompt(title: chunk.title, text: chunk.text), generating: GeneratedPlan.self)
                    .content
                parsedDays.append(contentsOf: generated.document(title: chunk.title, sourceText: chunk.text).trip.days)
            } catch {
                parsedDays.append(contentsOf: chunkFallback.trip.days)
            }
        }

        var merged = fallback
        if !parsedDays.isEmpty {
            merged.trip.days = parsedDays
            merged.generator = "Arc/1.0 (import-t1-chunked)"
        }

        return .parsed(merged)
    }

    @available(iOS 26.0, *)
    private func existingOrNewSession() -> LanguageModelSession {
        if let session {
            return session
        }

        let created = LanguageModelSession(
            instructions: """
            You convert creator trip notes into ArcPlanDocument-shaped field guides.
            Preserve source geography verbatim. Do not invent stops, coordinates, or events.
            Return structured output only.
            """
        )
        session = created
        return created
    }

    @available(iOS 26.0, *)
    private func prompt(title: String, text: String) -> String {
        """
        Build a structured Arc import plan.

        Required:
        - Preserve Google Maps links, addresses, and time-prefixed stop lines verbatim as sourceGeoAnchor.
        - Every item must include its source line, unless it is synthetic.
        - Use itemKind values: shot, voice, sound, transition, note.
        - Use priority values: must, optional.
        - Mark before-leaving items.
        - Keep days and stops in source order.

        Fallback title: \(title)

        Source:
        \(text)
        """
    }
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
private struct GeneratedPlan {
    var title: String
    var summary: String
    var days: [GeneratedDay]

    func document(title fallbackTitle: String, sourceText: String) -> ArcPlanDocument {
        let resolvedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallbackTitle : title
        return ArcPlanDocument(
            kind: .plan,
            generator: "Arc/1.0 (import-t1)",
            sourceText: sourceText,
            trip: ArcTripDocument(
                title: resolvedTitle,
                summary: summary,
                brief: ArcTripBriefDocument(
                    outputIntent: OutputIntent.fullTravelVlog.rawValue,
                    captureMedium: CaptureMedium.hybrid.rawValue,
                    targetPlatform: TargetPlatform.youtube.rawValue,
                    stylePreset: CaptureStylePreset.natural.rawValue
                ),
                artifacts: [
                    ArcTripArtifactDocument(kind: .shootList, title: "Imported Plan", body: sourceText)
                ],
                days: days.map(\.document)
            )
        )
    }
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedDay {
    var title: String
    var stops: [GeneratedStop]

    var document: ArcShootDayDocument {
        ArcShootDayDocument(title: title, stops: stops.map(\.document))
    }
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedStop {
    var title: String
    var placeName: String
    var sourceGeoAnchor: String
    var stages: [GeneratedStage]

    var document: ArcStopDocument {
        ArcStopDocument(
            title: title,
            placeName: placeName,
            geo: sourceGeoAnchor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ArcGeoDocument(sourceAnchor: sourceGeoAnchor),
            stages: stages.map(\.document)
        )
    }
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedStage {
    var title: String
    var goal: String
    var kind: String
    var items: [GeneratedItem]

    var document: ArcStageDocument {
        ArcStageDocument(
            title: title,
            goal: goal,
            kind: ArcStageDocumentKind(rawValue: kind) ?? .standard,
            items: items.map(\.document)
        )
    }
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedItem {
    var title: String
    var guidance: String
    var itemKind: String
    var priority: String
    var beforeLeaving: Bool
    var sourceLine: String
    var synthetic: Bool

    var document: ArcCaptureItemDocument {
        ArcCaptureItemDocument(
            title: title,
            guidance: guidance,
            itemKind: ArcCaptureItemKind(rawValue: itemKind) ?? .shot,
            priority: ArcCapturePriority(rawValue: priority) ?? .must,
            beforeLeaving: beforeLeaving,
            sourceLine: sourceLine,
            synthetic: synthetic
        )
    }
}
#endif

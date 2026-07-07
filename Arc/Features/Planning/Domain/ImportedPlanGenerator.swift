import Foundation

@MainActor
struct ImportedPlanGenerator {
    private let aiService: any AIServicing

    init(aiService: any AIServicing) {
        self.aiService = aiService
    }

    func improve(title: String, text: String) async throws -> FieldGuideDraft {
        try await improveDocument(title: title, text: text).fieldGuideDraft
    }

    func improveDocument(title: String, text: String) async throws -> ArcPlanDocument {
        let prompt = buildPrompt(title: title, text: text)
        let response = try await aiService.generateShotPlan(for: prompt)

        if let document = parseJSONDocument(title: title, sourceText: text, response: response) {
            return document
        }

        return ImportedPlanParser.parseDocument(title: title, text: response)
    }

    private func buildPrompt(title: String, text: String) -> String {
        """
        You are turning a creator's trip plan into a field execution guide.

        Project title: \(title)

        Return only valid JSON in this ArcPlanDocument shape:
        {
          "format": "arc.guide",
          "schemaVersion": 1,
          "kind": "plan",
          "generator": "Arc/1.0 (import-t2)",
          "sourceText": "verbatim source text",
          "unparsedRemainder": [],
          "trip": {
            "title": "\(title)",
            "summary": "One sentence about the story arc.",
            "brief": {
              "outputIntent": "fullTravelVlog",
              "captureMedium": "hybrid",
              "targetPlatform": "youtube",
              "stylePreset": "natural"
            },
            "artifacts": [
              { "kind": "shootList", "title": "Imported Plan", "body": "verbatim source text" }
            ],
            "days": [
              {
                "title": "Day 1",
                "date": null,
                "stops": [
                  {
                    "title": "Stop name",
                    "placeName": "Stop name",
                    "geo": { "lat": null, "lon": null, "resolved": false, "sourceAnchor": "verbatim maps URL, address, or time-prefix line" },
                    "plannedArrival": null,
                    "plannedDeparture": null,
                    "stages": [
                      {
                        "title": "Stage title",
                        "goal": "What this stage should establish in the edit.",
                        "kind": "standard",
                        "items": [
                          {
                            "title": "Short field checklist item",
                            "guidance": "Practical field guidance.",
                            "itemKind": "shot",
                            "priority": "must",
                            "beforeLeaving": false,
                            "sourceLine": "verbatim source line or empty for synthetic",
                            "synthetic": false
                          }
                        ]
                      }
                    ]
                  }
                ]
              }
            ]
          },
          "execution": null
        }

        Legacy fallback if the model cannot fill days/stops: return this simpler shape:
        {
          "story_summary": "One sentence about the story arc.",
          "stages": [
            {
              "title": "Stage title",
              "goal": "What this stage should establish in the edit.",
              "items": [
                {
                  "title": "Short field checklist item",
                  "kind": "shot",
                  "priority": "must | optional",
                  "guidance": "Practical field guidance.",
                  "before_leaving": false
                }
              ]
            }
          ]
        }

        Rules:
        - Create 5 to 14 stages when the plan supports it.
        - Keep each stage usable outside: 4 to 9 items.
        - Include at least one before_leaving item per stage.
        - Include voice, sound, transition, and ending coverage when relevant.
        - Do not invent locations or events that are not supported by the plan.
        - Preserve every maps URL, address, or time-prefixed stop line verbatim as geo.sourceAnchor.
        - Every item must carry sourceLine unless it is synthetic.
        - Do not return markdown or commentary.

        Source plan:
        \(text)
        """
    }

    private func parseJSONDocument(title: String, sourceText: String, response: String) -> ArcPlanDocument? {
        guard let root = jsonRoot(from: response) as? [String: Any] else {
            return nil
        }

        if let document = parseArcDocument(root, sourceText: sourceText) {
            return document
        }

        guard let rawStages = root["stages"] as? [[String: Any]] else {
            return nil
        }

        let stages = rawStages.compactMap(parseStage)
        guard !stages.isEmpty else {
            return nil
        }

        let summary = (root["story_summary"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ArcPlanDocument(
            kind: .plan,
            generator: "Arc/1.0 (import-t2-legacy)",
            sourceText: sourceText,
            trip: ArcTripDocument(
                title: title,
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
                days: [
                    ArcShootDayDocument(
                        title: "Day 1",
                        stops: [
                            ArcStopDocument(
                                title: title,
                                placeName: title,
                                stages: stages.map(\.arcStageDocument)
                            )
                        ]
                    )
                ]
            )
        )
    }

    private func parseArcDocument(_ root: [String: Any], sourceText: String) -> ArcPlanDocument? {
        guard root["format"] as? String == ArcPlanDocument.formatIdentifier else {
            return nil
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: root)
            var document = try ArcDocumentCodec.decodePlan(from: data)
            if document.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                document.sourceText = sourceText
            }
            document.generator = "Arc/1.0 (import-t2)"
            return document
        } catch {
            return nil
        }
    }

    private func parseStage(_ dictionary: [String: Any]) -> FieldGuideStageDraft? {
        guard let rawTitle = dictionary["title"] as? String else {
            return nil
        }

        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return nil
        }

        let goal = (dictionary["goal"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawItems = dictionary["items"] as? [[String: Any]] ?? []
        let items = rawItems.compactMap(parseItem)
        guard !items.isEmpty else {
            return nil
        }

        return FieldGuideStageDraft(title: title, goal: goal, items: items)
    }

    private func parseItem(_ dictionary: [String: Any]) -> FieldGuideItemDraft? {
        guard let rawTitle = dictionary["title"] as? String else {
            return nil
        }

        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return nil
        }

        let rawKind = (dictionary["kind"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawPriority = (dictionary["priority"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let guidance = (dictionary["guidance"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Capture this clearly enough to use in the edit."

        return FieldGuideItemDraft(
            title: title,
            guidance: guidance,
            kind: FieldGuideItemKind(rawValue: rawKind) ?? .shot,
            priority: FieldGuidePriority(rawValue: rawPriority) ?? .must,
            isBeforeLeaving: dictionary["before_leaving"] as? Bool ?? false,
            sourceLine: (dictionary["source_line"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            isSynthetic: dictionary["synthetic"] as? Bool ?? false
        )
    }

    private func jsonRoot(from response: String) -> Any? {
        let normalized = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let direct = parseJSON(normalized) {
            return direct
        }

        if let start = normalized.firstIndex(of: "{"),
           let end = normalized.lastIndex(of: "}") {
            return parseJSON(String(normalized[start...end]))
        }

        return nil
    }

    private func parseJSON(_ string: String) -> Any? {
        guard let data = string.data(using: .utf8) else {
            return nil
        }

        return try? JSONSerialization.jsonObject(with: data)
    }
}

private nonisolated extension FieldGuideStageDraft {
    var arcStageDocument: ArcStageDocument {
        ArcStageDocument(
            title: title,
            goal: goal,
            kind: items.contains(where: \.isBeforeLeaving) && title.localizedCaseInsensitiveContains("before") ? .beforeLeaving : .standard,
            items: items.map(\.arcItemDocument)
        )
    }
}

private nonisolated extension FieldGuideItemDraft {
    var arcItemDocument: ArcCaptureItemDocument {
        ArcCaptureItemDocument(
            title: title,
            guidance: guidance,
            itemKind: kind.documentKind,
            priority: priority.documentPriority,
            beforeLeaving: isBeforeLeaving,
            sourceLine: sourceLine,
            synthetic: isSynthetic
        )
    }
}

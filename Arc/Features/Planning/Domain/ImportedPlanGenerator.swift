import Foundation

@MainActor
struct ImportedPlanGenerator {
    private let aiService: any AIServicing

    init(aiService: any AIServicing) {
        self.aiService = aiService
    }

    func improve(title: String, text: String) async throws -> FieldGuideDraft {
        let prompt = buildPrompt(title: title, text: text)
        let response = try await aiService.generateShotPlan(for: prompt)

        if let draft = parseJSONDraft(title: title, response: response), !draft.stages.isEmpty {
            return draft
        }

        return ImportedPlanParser.parse(title: title, text: response)
    }

    private func buildPrompt(title: String, text: String) -> String {
        """
        You are turning a creator's trip plan into a field execution guide.

        Project title: \(title)

        Return only valid JSON in this shape:
        {
          "story_summary": "One sentence about the story arc.",
          "stages": [
            {
              "title": "Stage title",
              "goal": "What this stage should establish in the edit.",
              "items": [
                {
                  "title": "Short field checklist item",
                  "kind": "shot | voice | sound | transition | note",
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
        - Do not return markdown or commentary.

        Source plan:
        \(text)
        """
    }

    private func parseJSONDraft(title: String, response: String) -> FieldGuideDraft? {
        guard let root = jsonRoot(from: response) as? [String: Any] else {
            return nil
        }

        guard let rawStages = root["stages"] as? [[String: Any]] else {
            return nil
        }

        let stages = rawStages.compactMap(parseStage)
        guard !stages.isEmpty else {
            return nil
        }

        let summary = (root["story_summary"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return FieldGuideDraft(title: title, storySummary: summary, stages: stages)
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
            isBeforeLeaving: dictionary["before_leaving"] as? Bool ?? false
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

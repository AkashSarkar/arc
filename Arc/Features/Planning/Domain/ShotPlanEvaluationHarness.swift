import Foundation

struct ShotPlanEvaluationScores {
    let locationSpecificity: Int
    let narrativeCoherence: Int
    let temporalSensibility: Int
    let actionability: Int

    var overallAverage: Double {
        Double(locationSpecificity + narrativeCoherence + temporalSensibility + actionability) / 4
    }
}

struct ShotPlanEvaluationResult {
    let profileName: String
    let locationName: String
    let generatedAt: Date
    let draftCount: Int
    let scores: ShotPlanEvaluationScores?
    let errorDescription: String?
    let prompt: String
    let rawResponse: String
}

@MainActor
struct ShotPlanEvaluationHarness {
    typealias AIServiceFactory = (LLMProfile?) -> any AIServicing

    private let makeAIService: AIServiceFactory

    init(makeAIService: @escaping AIServiceFactory) {
        self.makeAIService = makeAIService
    }

    func evaluate(
        locations: [ShootLocation],
        profiles: [LLMProfile],
        input: ShotListGenerationInput
    ) async -> [ShotPlanEvaluationResult] {
        var results: [ShotPlanEvaluationResult] = []

        for profile in profiles {
            let generator = ShotListGenerator(aiService: makeAIService(profile))

            for location in locations {
                do {
                    let generation = try await generator.generate(for: location, input: input)
                    let scores = score(drafts: generation.drafts, location: location)

                    results.append(
                        ShotPlanEvaluationResult(
                            profileName: profile.name,
                            locationName: location.name,
                            generatedAt: Date(),
                            draftCount: generation.drafts.count,
                            scores: scores,
                            errorDescription: nil,
                            prompt: generation.prompt,
                            rawResponse: generation.rawResponse
                        )
                    )
                } catch {
                    results.append(
                        ShotPlanEvaluationResult(
                            profileName: profile.name,
                            locationName: location.name,
                            generatedAt: Date(),
                            draftCount: 0,
                            scores: nil,
                            errorDescription: error.localizedDescription,
                            prompt: "",
                            rawResponse: ""
                        )
                    )
                }
            }
        }

        return results
    }

    private func score(drafts: [PlannedShotDraft], location: ShootLocation) -> ShotPlanEvaluationScores {
        guard !drafts.isEmpty else {
            return ShotPlanEvaluationScores(
                locationSpecificity: 1,
                narrativeCoherence: 1,
                temporalSensibility: 1,
                actionability: 1
            )
        }

        let locationTerms = location.name
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 3 }

        let allText = drafts
            .map { "\($0.title) \($0.role) \($0.guidance)".lowercased() }
            .joined(separator: " ")

        let specificityHits = locationTerms.filter { allText.contains($0) }.count
        let roleVariety = Set(drafts.map { $0.role.lowercased() }).count
        let temporalHits = drafts.filter {
            let text = "\($0.title) \($0.guidance)".lowercased()
            return text.contains("sunrise")
                || text.contains("sunset")
                || text.contains("golden")
                || text.contains("blue hour")
                || text.contains("dawn")
                || text.contains("dusk")
                || text.contains("morning")
                || text.contains("evening")
        }.count

        let actionableHits = drafts.filter { draft in
            let guidance = draft.guidance.lowercased()
            return guidance.contains("mm")
                || guidance.contains("f/")
                || guidance.contains("iso")
                || guidance.contains("shutter")
                || guidance.contains("compose")
                || guidance.contains("framing")
        }.count

        return ShotPlanEvaluationScores(
            locationSpecificity: scoreFromRatio(Double(specificityHits), over: max(Double(locationTerms.count), 1)),
            narrativeCoherence: scoreFromRatio(Double(roleVariety), over: 6),
            temporalSensibility: scoreFromRatio(Double(temporalHits), over: Double(drafts.count)),
            actionability: scoreFromRatio(Double(actionableHits), over: Double(drafts.count))
        )
    }

    private func scoreFromRatio(_ numerator: Double, over denominator: Double) -> Int {
        guard denominator > 0 else { return 1 }

        let ratio = numerator / denominator
        switch ratio {
        case ..<0.2: return 1
        case ..<0.4: return 2
        case ..<0.6: return 3
        case ..<0.8: return 4
        default: return 5
        }
    }
}

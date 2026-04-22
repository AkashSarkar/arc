import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class PlanViewModel {
    private let shotListGenerator: any ShotListGenerating
    private let referenceImageCache: any ReferenceImageCaching
    private let calendar = Calendar.current

    var notes: String = ""
    var response: String = ""
    var errorMessage: String?
    var isLoading: Bool = false
    var isDraftApproved: Bool = false
    var cachedReferenceCount: Int = 0
    var cachedReferenceTotal: Int = 0
    var shootWindowMode: ShootWindowMode = .now
    var outputIntent: OutputIntent = .instagramCarousel
    var captureMedium: CaptureMedium = .photo
    var targetPlatform: TargetPlatform = .instagram
    var stylePreset: CaptureStylePreset = .natural
    var shootDate: Date = Date()
    var shootStartTime: Date = Date()
    var shootEndTime: Date = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()

    init(
        aiService: any AIServicing,
        existingPlan: ShootPlan? = nil,
        shotListGenerator: (any ShotListGenerating)? = nil,
        referenceImageCache: any ReferenceImageCaching = DiskReferenceImageCache()
    ) {
        self.shotListGenerator = shotListGenerator ?? ShotListGenerator(aiService: aiService)
        self.referenceImageCache = referenceImageCache

        guard let existingPlan else {
            return
        }

        notes = existingPlan.notes
        response = ShotPlanParser.formattedResponse(
            from: existingPlan.orderedItems.map {
                PlannedShotDraft(title: $0.title, role: $0.role, guidance: $0.guidance)
            },
            fallback: existingPlan.rawResponse
        )
        shootWindowMode = existingPlan.shootWindowMode
        outputIntent = existingPlan.outputIntent
        captureMedium = existingPlan.captureMedium
        targetPlatform = existingPlan.targetPlatform
        stylePreset = existingPlan.stylePreset
        shootDate = existingPlan.shootDate
        shootStartTime = existingPlan.shootStartTime
        shootEndTime = existingPlan.shootEndTime
        isDraftApproved = existingPlan.isApprovedForField
        if let location = existingPlan.location {
            let cacheStatus = referenceImageCache.cacheStatus(for: location)
            cachedReferenceCount = cacheStatus.cachedImages
            cachedReferenceTotal = cacheStatus.totalImages
        }
    }

    var shootWindowSummary: String {
        switch shootWindowMode {
        case .now:
            return "Use current conditions."
        case .custom:
            let window = customShootWindow()
            let dateText = window.start.formatted(date: .abbreviated, time: .omitted)
            let startText = window.start.formatted(date: .omitted, time: .shortened)
            let endText = window.end.formatted(date: .omitted, time: .shortened)
            return "\(dateText), \(startText) to \(endText)."
        }
    }

    var shootWindowInterval: DateInterval? {
        switch shootWindowMode {
        case .now:
            let start = Date()
            return DateInterval(start: start, end: start.addingTimeInterval(2 * 3600))
        case .custom:
            let window = customShootWindow()
            guard window.end > window.start else {
                return nil
            }

            return DateInterval(start: window.start, end: window.end)
        }
    }

    func generatePlan(for location: ShootLocation, modelContext: ModelContext) async {
        guard let generationResult = await generatePreview(for: location) else {
            return
        }

        await applyGeneratedPlan(
            rawResponse: generationResult.rawResponse,
            drafts: generationResult.drafts,
            for: location,
            modelContext: modelContext,
            approve: false
        )
    }

    func generatePreview(for location: ShootLocation) async -> ShotListGenerationResult? {
        guard let input = generationInput() else {
            return nil
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let generationResult = try await shotListGenerator.generate(for: location, input: input)
            response = ShotPlanParser.formattedResponse(from: generationResult.drafts, fallback: generationResult.rawResponse)
            return generationResult
        } catch {
            response = ""
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func applyGeneratedPlan(
        rawResponse: String,
        drafts: [PlannedShotDraft],
        for location: ShootLocation,
        modelContext: ModelContext,
        approve: Bool
    ) async -> Bool {
        guard !drafts.isEmpty else {
            errorMessage = "Arc could not create a usable shot list. Try regenerating."
            return false
        }

        errorMessage = nil

        persistPlan(
            for: location,
            rawResponse: rawResponse,
            drafts: drafts,
            approve: approve,
            modelContext: modelContext
        )

        do {
            try modelContext.save()
            let cacheResult = await referenceImageCache.cacheReferenceImages(for: location)
            response = ShotPlanParser.formattedResponse(from: drafts, fallback: rawResponse)

            if cacheResult.totalImages > 0, cacheResult.cachedImages == 0 {
                errorMessage = "Plan generated, but reference image caching failed. You may need connectivity for image previews."
            }

            cachedReferenceCount = cacheResult.cachedImages
            cachedReferenceTotal = cacheResult.totalImages
            isDraftApproved = approve
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func approveDraft(for location: ShootLocation, modelContext: ModelContext) {
        guard let plan = location.plan, !plan.items.isEmpty else {
            errorMessage = "Generate a draft before saving."
            return
        }

        plan.isApprovedForField = true
        plan.approvedAt = Date()
        plan.completedAt = nil
        isDraftApproved = true
        errorMessage = nil

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func ensureDefaultWindowTimes() {
        if shootEndTime <= shootStartTime,
           let adjustedEnd = calendar.date(byAdding: .hour, value: 2, to: shootStartTime) {
            shootEndTime = adjustedEnd
        }
    }

    func refreshReferenceCacheStatus(for location: ShootLocation) {
        let status = referenceImageCache.cacheStatus(for: location)
        cachedReferenceCount = status.cachedImages
        cachedReferenceTotal = status.totalImages
    }

    func applyOutputDefaults() {
        captureMedium = outputIntent.defaultCaptureMedium
        targetPlatform = outputIntent.defaultTargetPlatform
    }

    private func generationInput() -> ShotListGenerationInput? {
        switch shootWindowMode {
        case .now:
            return ShotListGenerationInput(
                outputIntent: outputIntent,
                captureMedium: captureMedium,
                targetPlatform: targetPlatform,
                stylePreset: stylePreset,
                notes: notes,
                shootWindowMode: .now,
                shootWindowStart: Date(),
                shootWindowEnd: Date().addingTimeInterval(2 * 3600)
            )
        case .custom:
            let window = customShootWindow()
            guard window.end > window.start else {
                errorMessage = "End time must be after start time."
                return nil
            }

            return ShotListGenerationInput(
                outputIntent: outputIntent,
                captureMedium: captureMedium,
                targetPlatform: targetPlatform,
                stylePreset: stylePreset,
                notes: notes,
                shootWindowMode: .custom,
                shootWindowStart: window.start,
                shootWindowEnd: window.end
            )
        }
    }

    private func customShootWindow() -> (start: Date, end: Date) {
        let start = combine(date: shootDate, time: shootStartTime)
        let end = combine(date: shootDate, time: shootEndTime)
        return (start, end)
    }

    private func combine(date: Date, time: Date) -> Date {
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        let mergedComponents = DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: timeComponents.hour,
            minute: timeComponents.minute
        )

        return calendar.date(from: mergedComponents) ?? date
    }

    private func persistPlan(
        for location: ShootLocation,
        rawResponse: String,
        drafts: [PlannedShotDraft],
        approve: Bool,
        modelContext: ModelContext
    ) {
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = location.plan ?? ShootPlan(location: location)

        if location.plan == nil {
            location.plan = plan
            modelContext.insert(plan)
        }

        plan.createdAt = Date()
        plan.notes = cleanNotes
        plan.rawResponse = rawResponse
        plan.outputIntentRawValue = outputIntent.rawValue
        plan.captureMediumRawValue = captureMedium.rawValue
        plan.targetPlatformRawValue = targetPlatform.rawValue
        plan.stylePresetRawValue = stylePreset.rawValue
        plan.shootWindowModeRawValue = shootWindowMode.rawValue
        plan.shootWindowSummary = shootWindowSummary
        plan.shootDate = shootDate
        plan.shootStartTime = shootStartTime
        plan.shootEndTime = shootEndTime
        plan.isApprovedForField = approve
        plan.approvedAt = approve ? Date() : nil
        plan.completedAt = nil

        for existingItem in Array(plan.items) {
            modelContext.delete(existingItem)
        }
        plan.items.removeAll()

        for (index, draft) in drafts.enumerated() {
            let item = ShootPlanItem(
                orderIndex: index,
                title: draft.title,
                role: draft.role,
                guidance: draft.guidance,
                plan: plan
            )
            modelContext.insert(item)
            plan.items.append(item)
        }
    }
}

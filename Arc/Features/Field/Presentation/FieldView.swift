import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct FieldView: View {
    let location: ShootLocation
    let aiService: any AIServicing
    let locationEnricher: any LocationEnriching
    let referenceImageCache: any ReferenceImageCaching
    let locationEditorServices: LocationEditorServiceFactory

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("Arc.FieldHighContrastMode") private var isHighContrastMode = false
    @State private var cacheStatus = ReferenceImageCacheResult(totalImages: 0, cachedImages: 0)
    @State private var isPresentingInfo = false
    @State private var isPresentingPlanEditor = false
    @State private var isPresentingEditLocation = false
    @State private var isPresentingSafetyNet = false
    @State private var isConfirmingDelete = false
    @State private var isConfirmingFinish = false
    @State private var isConfirmingStageAdvance = false
    @State private var pendingStageOrderIndex: Int?
    @State private var hasDismissedCompletionPrompt = false
    @State private var photoAttachmentError: String?
    @State private var editingNoteItem: ShootPlanItem?

    private var plan: ShootPlan? {
        guard let existingPlan = location.plan,
              existingPlan.isApprovedForField,
              existingPlan.completedAt == nil
        else {
            return nil
        }

        return existingPlan
    }

    private var isImportedPlan: Bool {
        plan?.source == .importedText
    }

    private var planItems: [ShootPlanItem] {
        plan?.orderedItems ?? []
    }

    private var fieldStages: [FieldGuideStage] {
        plan?.fieldStages ?? []
    }

    private var currentStage: FieldGuideStage? {
        plan?.currentStage
    }

    private var currentStagePosition: Int? {
        guard let currentStage else {
            return nil
        }

        return fieldStages.firstIndex { $0.orderIndex == currentStage.orderIndex }
    }

    private var hasPlanItems: Bool {
        !planItems.isEmpty
    }

    private var nextPendingItem: ShootPlanItem? {
        currentStage?.items.first(where: { !$0.isResolved }) ?? planItems.first(where: { !$0.isResolved })
    }

    private var remainingCount: Int {
        plan?.missingCount ?? 0
    }

    private var completionProgress: Double {
        plan?.fieldCompletionProgress ?? 0
    }

    private var shouldShowCompletionPrompt: Bool {
        hasPlanItems && remainingCount == 0 && !hasDismissedCompletionPrompt
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                FieldExecutionHeader(
                    locationName: location.name,
                    plan: plan,
                    currentStage: currentStage,
                    referenceStatus: referenceStatusText,
                    isHighContrast: isHighContrastMode
                )

                if hasPlanItems, let plan {
                    FieldProgressPanel(
                        completedCount: plan.capturedCount,
                        skippedCount: plan.skippedCount,
                        totalCount: planItems.count,
                        remainingCount: remainingCount,
                        progress: completionProgress,
                        isHighContrast: isHighContrastMode
                    )
                }

                if let photoAttachmentError {
                    ArcInlineError(message: photoAttachmentError)
                        .padding(.horizontal, 2)
                }

                if hasPlanItems, let stage = currentStage {
                    FieldStageNavigator(
                        stage: stage,
                        currentPosition: currentStagePosition ?? 0,
                        totalStages: fieldStages.count,
                        isHighContrast: isHighContrastMode,
                        previousAction: previousStage,
                        nextAction: attemptNextStage
                    )

                    FieldStageCard(
                        stage: stage,
                        isHighContrast: isHighContrastMode,
                        toggleCaptured: toggleItemCompletion,
                        toggleSkipped: toggleItemSkipped,
                        attachPhoto: attachPhoto,
                        removePhoto: removePhoto,
                        editNote: { editingNoteItem = $0 }
                    )

                    if let plan {
                        FieldGuidanceCard(
                            location: location,
                            plan: plan,
                            isHighContrast: isHighContrastMode
                        )
                    }
                } else {
                    FieldPlanRequiredCard()
                }
            }
            .padding(16)
            .padding(.bottom, hasPlanItems ? 112 : 0)
        }
        .background(fieldBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if hasPlanItems {
                fieldActionBar
            }
        }
        .navigationTitle("Field Guide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isHighContrastMode.toggle()
                    }
                    playImpact(.light)
                } label: {
                    Image(systemName: isHighContrastMode ? "sun.max.fill" : "sun.max")
                }
                .accessibilityLabel(isHighContrastMode ? "Disable high contrast mode" : "Enable high contrast mode")

                if hasPlanItems {
                    Button {
                        isPresentingSafetyNet = true
                    } label: {
                        Image(systemName: "lifepreserver")
                    }
                    .accessibilityLabel("Open story safety net")
                }

                if !isImportedPlan {
                    Button {
                        isPresentingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("Plan info")
                }

                Button {
                    isPresentingPlanEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit plan")
                .disabled(location.plan == nil)

                Menu {
                    if !isImportedPlan {
                        Button {
                            isPresentingEditLocation = true
                        } label: {
                            Label("Edit Location", systemImage: "slider.horizontal.3")
                        }
                    }

                    Toggle(isOn: $isHighContrastMode) {
                        Label("High Contrast", systemImage: "sun.max")
                    }

                    Button {
                        isConfirmingFinish = true
                    } label: {
                        Label("Complete Plan", systemImage: "checkmark.seal")
                    }
                    .disabled(!hasPlanItems)

                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete Plan", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More actions")
            }
        }
        .sheet(isPresented: $isPresentingInfo) {
            ShootInfoSheet(
                location: location,
                locationEnricher: locationEnricher,
                referenceImageCache: referenceImageCache,
                locationEditorServices: locationEditorServices
            )
        }
        .sheet(isPresented: $isPresentingPlanEditor) {
            PlanEditorSheet(
                location: location,
                aiService: aiService,
                locationEnricher: locationEnricher,
                referenceImageCache: referenceImageCache
            )
        }
        .sheet(isPresented: $isPresentingEditLocation) {
            LocationEditorView(location: location, services: locationEditorServices) { draft in
                location.name = draft.name
                location.latitude = draft.coordinate.latitude
                location.longitude = draft.coordinate.longitude
            }
        }
        .sheet(isPresented: $isPresentingSafetyNet) {
            SafetyNetSheet(addItems: addSafetyNetItems)
        }
        .sheet(item: $editingNoteItem) { item in
            FieldNoteEditorSheet(item: item) {
                saveChanges()
            }
        }
        .confirmationDialog("Complete this plan?", isPresented: $isConfirmingFinish, titleVisibility: .visible) {
            Button("Complete Plan") {
                finishShoot()
            }

            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("The capture plan will move to Completed. You can reopen it later.")
        }
        .confirmationDialog("Move to the next stage?", isPresented: $isConfirmingStageAdvance, titleVisibility: .visible) {
            Button("Move Anyway") {
                advanceToPendingStage()
            }

            Button("Cancel", role: .cancel) {
                pendingStageOrderIndex = nil
            }
        } message: {
            Text(stageAdvanceWarningText)
        }
        .confirmationDialog("Delete this plan?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Plan", role: .destructive) {
                deleteShoot()
            }

            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("This removes the location, capture plan, and shot list.")
        }
        .task(id: location.enrichmentJSON) {
            cacheStatus = referenceImageCache.cacheStatus(for: location)
        }
    }

    @ViewBuilder
    private var fieldBackground: some View {
        if isHighContrastMode {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
        } else {
            ArcSceneBackground()
        }
    }

    private var referenceStatusText: String? {
        guard !isImportedPlan, cacheStatus.totalImages > 0 else {
            return nil
        }

        return "References \(cacheStatus.cachedImages)/\(cacheStatus.totalImages)"
    }

    @ViewBuilder
    private var fieldActionBar: some View {
        if shouldShowCompletionPrompt {
            ArcBottomActionBar(
                title: "Field guide wrapped",
                subtitle: "Complete to move this plan to Completed.",
                primaryTitle: "Complete Plan",
                primarySystemImage: "checkmark.seal",
                secondaryTitle: "Keep Open",
                secondarySystemImage: "xmark",
                usesSolidBackground: isHighContrastMode,
                primaryAction: { isConfirmingFinish = true },
                secondaryAction: { hasDismissedCompletionPrompt = true }
            )
        } else if currentStage?.missingItems.isEmpty == true {
            ArcBottomActionBar(
                title: "Stage wrapped",
                subtitle: "\(remainingCount) items left in the full guide.",
                primaryTitle: isLastStage ? "Complete Plan" : "Next Stage",
                primarySystemImage: isLastStage ? "checkmark.seal" : "arrow.right",
                secondaryTitle: "Reset Stage",
                secondarySystemImage: "arrow.counterclockwise",
                usesSolidBackground: isHighContrastMode,
                primaryAction: {
                    if isLastStage {
                        isConfirmingFinish = true
                    } else {
                        attemptNextStage()
                    }
                },
                secondaryAction: resetCurrentStage
            )
        } else {
            ArcBottomActionBar(
                title: nextPendingItem?.title ?? "Next field item",
                subtitle: "\(remainingCount) unresolved • \(completionProgress.formatted(.percent.precision(.fractionLength(0)))) complete",
                primaryTitle: "Mark Next",
                primarySystemImage: "checkmark.circle.fill",
                secondaryTitle: isLastStage ? "Safety Net" : "Next Stage",
                secondarySystemImage: isLastStage ? "lifepreserver" : "arrow.right",
                usesSolidBackground: isHighContrastMode,
                primaryAction: completeNextItem,
                secondaryAction: {
                    if isLastStage {
                        isPresentingSafetyNet = true
                    } else {
                        attemptNextStage()
                    }
                }
            )
        }
    }

    private var isLastStage: Bool {
        guard let currentStagePosition else {
            return true
        }

        return currentStagePosition >= fieldStages.count - 1
    }

    private var stageAdvanceWarningText: String {
        let titles = blockingItemsForStageAdvance.map(\.title)
        guard !titles.isEmpty else {
            return "Some current-stage items are still unresolved."
        }

        return "Still missing: \(titles.prefix(4).joined(separator: ", "))."
    }

    private var blockingItemsForStageAdvance: [ShootPlanItem] {
        guard let currentStage else {
            return []
        }

        return currentStage.items.filter { item in
            !item.isResolved && (item.priority == .must || item.isBeforeLeaving)
        }
    }

    private func toggleItemCompletion(_ item: ShootPlanItem) {
        withAnimation(.easeInOut(duration: 0.18)) {
            item.isCaptured.toggle()
            if item.isCaptured {
                item.isSkipped = false
            }
        }

        photoAttachmentError = nil
        hasDismissedCompletionPrompt = false
        playImpact(item.isCaptured ? .medium : .light)
        saveChanges()
    }

    private func toggleItemSkipped(_ item: ShootPlanItem) {
        withAnimation(.easeInOut(duration: 0.18)) {
            item.isSkipped.toggle()
            if item.isSkipped {
                item.isCaptured = false
            }
        }

        photoAttachmentError = nil
        hasDismissedCompletionPrompt = false
        playImpact(.light)
        saveChanges()
    }

    private func completeNextItem() {
        guard let nextPendingItem else {
            return
        }

        toggleItemCompletion(nextPendingItem)
    }

    private func resetCurrentStage() {
        withAnimation(.easeInOut(duration: 0.18)) {
            for item in currentStage?.items ?? [] {
                item.isCaptured = false
                item.isSkipped = false
            }
        }

        photoAttachmentError = nil
        hasDismissedCompletionPrompt = false
        playImpact(.heavy)
        saveChanges()
    }

    private func previousStage() {
        guard let currentStagePosition, currentStagePosition > 0, let plan else {
            return
        }

        plan.currentStageOrderIndex = fieldStages[currentStagePosition - 1].orderIndex
        saveChanges()
        playImpact(.light)
    }

    private func attemptNextStage() {
        guard let currentStagePosition, currentStagePosition < fieldStages.count - 1 else {
            return
        }

        pendingStageOrderIndex = fieldStages[currentStagePosition + 1].orderIndex
        if blockingItemsForStageAdvance.isEmpty {
            advanceToPendingStage()
        } else {
            isConfirmingStageAdvance = true
        }
    }

    private func advanceToPendingStage() {
        guard let pendingStageOrderIndex, let plan else {
            return
        }

        plan.currentStageOrderIndex = pendingStageOrderIndex
        self.pendingStageOrderIndex = nil
        saveChanges()
        playImpact(.light)
    }

    private func finishShoot() {
        guard let plan else {
            return
        }

        plan.completedAt = Date()
        saveChanges()
        playNotification(.success)
        dismiss()
    }

    private func deleteShoot() {
        modelContext.delete(location)
        saveChanges()
        playNotification(.warning)
        dismiss()
    }

    private func attachPhoto(_ pickerItem: PhotosPickerItem?, to item: ShootPlanItem) {
        guard let pickerItem else {
            return
        }

        Task {
            do {
                guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                    photoAttachmentError = "Arc could not load that image."
                    playNotification(.error)
                    return
                }

                let storedData = compressedImageData(from: data) ?? data

                withAnimation(.easeInOut(duration: 0.18)) {
                    item.capturedPhotoData = storedData
                    item.capturedPhotoAttachedAt = Date()
                    item.isCaptured = true
                    item.isSkipped = false
                }

                photoAttachmentError = nil
                hasDismissedCompletionPrompt = false
                saveChanges()
                playNotification(.success)
            } catch {
                photoAttachmentError = error.localizedDescription
                playNotification(.error)
            }
        }
    }

    private func removePhoto(from item: ShootPlanItem) {
        withAnimation(.easeInOut(duration: 0.18)) {
            item.capturedPhotoData = nil
            item.capturedPhotoAttachedAt = nil
        }

        photoAttachmentError = nil
        saveChanges()
        playImpact(.light)
    }

    private func addSafetyNetItems() {
        guard let plan, let currentStage else {
            return
        }

        let nextOrderIndex = (planItems.map(\.orderIndex).max() ?? -1) + 1
        let drafts = [
            FieldGuideItemDraft(title: "Wide shot of where you are", guidance: "Hold for at least 8 to 10 seconds.", kind: .shot, priority: .must),
            FieldGuideItemDraft(title: "Close-up of one useful detail", guidance: "Capture texture, sign, food, gear, hands, or an object.", kind: .shot, priority: .must),
            FieldGuideItemDraft(title: "Hands or feet doing something", guidance: "Give the edit a human action cutaway.", kind: .shot, priority: .optional),
            FieldGuideItemDraft(title: "Natural sound", guidance: "Record 10 seconds without talking.", kind: .sound, priority: .must),
            FieldGuideItemDraft(title: "Honest reaction", guidance: "Say one line about what changed, surprised you, or mattered.", kind: .voice, priority: .must),
            FieldGuideItemDraft(title: "Leaving shot", guidance: "Show yourself moving on from this place.", kind: .transition, priority: .must, isBeforeLeaving: true)
        ]

        let unresolvedTitles = Set(
            currentStage.items
                .filter { !$0.isResolved }
                .map { normalizedSafetyNetTitle($0.title) }
        )
        var appendedCount = 0

        for draft in drafts where !unresolvedTitles.contains(normalizedSafetyNetTitle(draft.title)) {
            let item = ShootPlanItem(
                orderIndex: nextOrderIndex + appendedCount,
                title: draft.title,
                role: "Safety Net",
                guidance: draft.guidance,
                stageTitle: currentStage.title,
                stageOrderIndex: currentStage.orderIndex,
                stageGoal: currentStage.goal,
                kind: draft.kind,
                priority: draft.priority,
                isBeforeLeaving: draft.isBeforeLeaving,
                plan: plan
            )
            modelContext.insert(item)
            plan.items.append(item)
            appendedCount += 1
        }

        saveChanges()
        isPresentingSafetyNet = false
        playNotification(.success)
    }

    private func saveChanges() {
        try? modelContext.save()
    }

    private func normalizedSafetyNetTitle(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func compressedImageData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else {
            return nil
        }

        let maxSide: CGFloat = 1_600
        let size = image.size
        let longestSide = max(size.width, size.height)
        let scale = longestSide > maxSide ? maxSide / longestSide : 1
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resizedImage.jpegData(compressionQuality: 0.76)
    }

    private func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func playNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

private struct FieldExecutionHeader: View {
    let locationName: String
    let plan: ShootPlan?
    let currentStage: FieldGuideStage?
    let referenceStatus: String?
    let isHighContrast: Bool

    var body: some View {
        ArcCompactHeroHeader(
            systemImage: plan?.source == .importedText ? "rectangle.stack.fill" : "checklist.checked",
            title: locationName,
            summary: summary,
            tint: ArcPalette.tint
        )

        if let plan {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ArcStatusPill(plan.source.title, systemImage: plan.source == .importedText ? "square.and.arrow.down" : "mappin.and.ellipse")
                    ArcStatusPill(plan.outputIntent.title, systemImage: "square.stack.3d.up")
                    ArcStatusPill(plan.captureMedium.title, systemImage: "camera", tint: ArcPalette.tint)
                    ArcStatusPill(plan.targetPlatform.title, systemImage: "paperplane", tint: ArcPalette.glowPrimary)

                    if let referenceStatus {
                        ArcStatusPill(referenceStatus, systemImage: "arrow.down.circle", tint: ArcPalette.tint)
                    }
                }
            }
        }

        if isHighContrast {
            ArcStatusPill("High Contrast", systemImage: "sun.max.fill", tint: ArcPalette.tint)
        }
    }

    private var summary: String {
        guard let plan else {
            return "No active field guide"
        }

        if let currentStage {
            if !currentStage.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return currentStage.goal
            }

            return "Current stage: \(currentStage.title)"
        }

        return "\(plan.outputIntent.title) - \(plan.captureMedium.title) - \(plan.targetPlatform.title)"
    }
}

private struct FieldProgressPanel: View {
    let completedCount: Int
    let skippedCount: Int
    let totalCount: Int
    let remainingCount: Int
    let progress: Double
    let isHighContrast: Bool

    var body: some View {
        ArcDenseCard(accent: ArcPalette.tint) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    ArcMetricTile(title: "Captured", value: "\(completedCount)", systemImage: "checkmark.circle", accent: ArcPalette.tint)
                    ArcMetricTile(title: "Skipped", value: "\(skippedCount)", systemImage: "forward.circle", accent: ArcPalette.glowSecondary)
                    ArcMetricTile(title: "Missing", value: "\(remainingCount)", systemImage: "circle.dashed", accent: ArcPalette.glowPrimary)
                }

                VStack(spacing: 10) {
                    ArcMetricTile(title: "Captured", value: "\(completedCount)", systemImage: "checkmark.circle", accent: ArcPalette.tint)
                    ArcMetricTile(title: "Skipped", value: "\(skippedCount)", systemImage: "forward.circle", accent: ArcPalette.glowSecondary)
                    ArcMetricTile(title: "Missing", value: "\(remainingCount)", systemImage: "circle.dashed", accent: ArcPalette.glowPrimary)
                }
            }

            FieldProgressSection(
                progress: progress,
                resolvedText: "\(completedCount + skippedCount)/\(totalCount) resolved",
                isHighContrast: isHighContrast
            )
        }
    }
}

private struct FieldStageNavigator: View {
    let stage: FieldGuideStage
    let currentPosition: Int
    let totalStages: Int
    let isHighContrast: Bool
    let previousAction: () -> Void
    let nextAction: () -> Void

    var body: some View {
        ArcDenseCard(accent: ArcPalette.glowSecondary) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Stage \(currentPosition + 1) of \(totalStages)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(stage.title)
                        .font(isHighContrast ? .title2.weight(.semibold) : .headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !stage.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label(stage.goal, systemImage: "scope")
                            .font(isHighContrast ? .body.weight(.medium) : .subheadline.weight(.medium))
                            .foregroundStyle(isHighContrast ? .primary : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("\(stage.resolvedCount)/\(stage.items.count) resolved")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Button(action: previousAction) {
                        Image(systemName: "chevron.left")
                            .frame(width: 38, height: 30)
                    }
                    .buttonStyle(.glass)
                    .disabled(currentPosition == 0)
                    .accessibilityLabel("Previous stage")

                    Button(action: nextAction) {
                        Image(systemName: "chevron.right")
                            .frame(width: 38, height: 30)
                    }
                    .buttonStyle(.glass)
                    .disabled(currentPosition >= totalStages - 1)
                    .accessibilityLabel("Next stage")
                }
            }

            FieldProgressBar(progress: stage.progress)
                .frame(height: 8)
        }
    }
}

private struct FieldStageCard: View {
    let stage: FieldGuideStage
    let isHighContrast: Bool
    let toggleCaptured: (ShootPlanItem) -> Void
    let toggleSkipped: (ShootPlanItem) -> Void
    let attachPhoto: (PhotosPickerItem?, ShootPlanItem) -> Void
    let removePhoto: (ShootPlanItem) -> Void
    let editNote: (ShootPlanItem) -> Void

    private var mustCaptureItems: [ShootPlanItem] {
        stage.items.filter { !$0.isBeforeLeaving && $0.priority == .must && ![.voice, .sound, .transition].contains($0.kind) }
    }

    private var optionalItems: [ShootPlanItem] {
        stage.items.filter { !$0.isBeforeLeaving && $0.priority == .optional && ![.voice, .sound, .transition].contains($0.kind) }
    }

    private var voiceSoundTransitionItems: [ShootPlanItem] {
        stage.items.filter { !$0.isBeforeLeaving && [.voice, .sound, .transition].contains($0.kind) }
    }

    private var beforeLeavingItems: [ShootPlanItem] {
        stage.items.filter(\.isBeforeLeaving)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FieldItemSection(
                title: "Must Capture",
                systemImage: "checklist",
                items: mustCaptureItems,
                emptyText: "No must-capture items in this stage.",
                isHighContrast: isHighContrast,
                toggleCaptured: toggleCaptured,
                toggleSkipped: toggleSkipped,
                attachPhoto: attachPhoto,
                removePhoto: removePhoto,
                editNote: editNote
            )

            FieldItemSection(
                title: "Voice / Sound / Transition",
                systemImage: "waveform",
                items: voiceSoundTransitionItems,
                emptyText: "No voice, sound, or transition prompts.",
                isHighContrast: isHighContrast,
                toggleCaptured: toggleCaptured,
                toggleSkipped: toggleSkipped,
                attachPhoto: attachPhoto,
                removePhoto: removePhoto,
                editNote: editNote
            )

            FieldItemSection(
                title: "Optional",
                systemImage: "sparkles",
                items: optionalItems,
                emptyText: "No optional items in this stage.",
                isHighContrast: isHighContrast,
                toggleCaptured: toggleCaptured,
                toggleSkipped: toggleSkipped,
                attachPhoto: attachPhoto,
                removePhoto: removePhoto,
                editNote: editNote
            )

            FieldItemSection(
                title: "Before You Leave",
                systemImage: "figure.walk.departure",
                items: beforeLeavingItems,
                emptyText: "No before-leaving checks.",
                isHighContrast: isHighContrast,
                toggleCaptured: toggleCaptured,
                toggleSkipped: toggleSkipped,
                attachPhoto: attachPhoto,
                removePhoto: removePhoto,
                editNote: editNote
            )
        }
        .padding(isHighContrast ? 18 : 20)
        .background(isHighContrast ? Color(uiColor: .secondarySystemBackground) : ArcPalette.solidFieldSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isHighContrast ? Color.primary.opacity(0.20) : ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct FieldItemSection: View {
    let title: String
    let systemImage: String
    let items: [ShootPlanItem]
    let emptyText: String
    let isHighContrast: Bool
    let toggleCaptured: (ShootPlanItem) -> Void
    let toggleSkipped: (ShootPlanItem) -> Void
    let attachPhoto: (PhotosPickerItem?, ShootPlanItem) -> Void
    let removePhoto: (ShootPlanItem) -> Void
    let editNote: (ShootPlanItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ArcFeatureTitle(
                systemImage: systemImage,
                title: title,
                subtitle: items.isEmpty ? nil : "\(items.filter(\.isResolved).count)/\(items.count) resolved",
                accent: title == "Before You Leave" ? ArcPalette.glowPrimary : ArcPalette.tint
            )

            if items.isEmpty {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    FieldChecklistRow(
                        item: item,
                        isHighContrast: isHighContrast,
                        toggleCaptured: { toggleCaptured(item) },
                        toggleSkipped: { toggleSkipped(item) },
                        attachPhoto: { pickerItem in attachPhoto(pickerItem, item) },
                        removePhoto: { removePhoto(item) },
                        editNote: { editNote(item) }
                    )
                }
            }
        }
    }
}

private struct FieldChecklistRow: View {
    let item: ShootPlanItem
    let isHighContrast: Bool
    let toggleCaptured: () -> Void
    let toggleSkipped: () -> Void
    let attachPhoto: (PhotosPickerItem?) -> Void
    let removePhoto: () -> Void
    let editNote: () -> Void

    private var thumbnailImage: UIImage? {
        guard let data = item.capturedPhotoData else {
            return nil
        }

        return UIImage(data: data)
    }

    var body: some View {
        let hasAttachedPhoto = item.capturedPhotoData != nil

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Button(action: toggleCaptured) {
                    Image(systemName: item.isCaptured ? "checkmark.circle.fill" : "circle")
                        .font((isHighContrast ? Font.title2 : .title3).weight(.semibold))
                        .foregroundStyle(item.isCaptured ? ArcPalette.tint : .secondary)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isCaptured ? "Mark not captured" : "Mark captured")

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(item.title)
                            .font(isHighContrast ? .title3.weight(.semibold) : .headline)
                            .foregroundStyle(item.isSkipped ? .secondary : .primary)
                            .strikethrough(item.isSkipped)

                        Spacer(minLength: 0)

                        HStack(spacing: 6) {
                            ArcStatusPill(item.displayRoleTitle, systemImage: item.kind.systemImage, tint: item.isBeforeLeaving ? ArcPalette.glowPrimary : ArcPalette.tint)

                            if item.priority == .must {
                                ArcStatusPill("Must", systemImage: "exclamationmark", tint: ArcPalette.glowPrimary)
                            }
                        }
                    }

                    Text(item.guidance)
                        .font(isHighContrast ? .body : .subheadline)
                        .foregroundStyle(isHighContrast ? .primary : .secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !item.fieldNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label(item.fieldNote, systemImage: "note.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        ArcStatusPill("Snap attached", systemImage: "photo.fill", tint: ArcPalette.tint)
                            .padding(8)
                    }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    actionButtons(hasAttachedPhoto: hasAttachedPhoto)
                }

                VStack(spacing: 8) {
                    actionButtons(hasAttachedPhoto: hasAttachedPhoto)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(isHighContrast ? 20 : 18)
        .background(isHighContrast ? Color(uiColor: .systemBackground) : ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(rowStrokeColor, lineWidth: isHighContrast ? 1.5 : 1)
        }
    }

    private var rowStrokeColor: Color {
        if item.isCaptured {
            return ArcPalette.tint.opacity(isHighContrast ? 0.75 : 0.45)
        }

        if item.isSkipped {
            return ArcPalette.glowSecondary.opacity(isHighContrast ? 0.75 : 0.45)
        }

        return isHighContrast ? Color.primary.opacity(0.20) : ArcPalette.surfaceStroke
    }

    private func actionButtons(hasAttachedPhoto: Bool) -> some View {
        Group {
            Button(action: toggleSkipped) {
                Label(item.isSkipped ? "Unskip" : "Skip", systemImage: "forward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)

            Button(action: editNote) {
                Label(item.fieldNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Note" : "Edit Note", systemImage: "note.text")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)

            PhotosPicker(
                selection: Binding<PhotosPickerItem?>(
                    get: { nil },
                    set: { attachPhoto($0) }
                ),
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(hasAttachedPhoto ? "Replace" : "Snap", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)

            if hasAttachedPhoto {
                Button(role: .destructive, action: removePhoto) {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 20)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Remove attached snap")
            }
        }
    }
}

private struct FieldGuidanceCard: View {
    let location: ShootLocation
    let plan: ShootPlan
    let isHighContrast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ArcFeatureTitle(
                systemImage: "eye.fill",
                title: plan.source == .importedText ? "Story Guide" : "Reminders",
                subtitle: nil,
                accent: ArcPalette.glowSecondary
            )

            if plan.source == .importedText, !plan.storySummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(plan.storySummary)
                    .font(isHighContrast ? .body : .subheadline)
                    .foregroundStyle(isHighContrast ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                FieldGuidanceRow(
                    systemImage: "sparkles.rectangle.stack",
                    title: "Stay on brief",
                    subtitle: "Keep the \(plan.outputIntent.title) set coherent while capturing \(location.name)."
                )

                FieldGuidanceRow(
                    systemImage: "mountain.2.fill",
                    title: "Open wide first",
                    subtitle: "Anchor \(location.name) before moving into details."
                )

                FieldGuidanceRow(
                    systemImage: "rectangle.portrait.and.arrow.right",
                    title: "Grab one vertical cutaway",
                    subtitle: "Leave with one detail or motion frame for the edit."
                )
            }
        }
        .padding(20)
        .background(isHighContrast ? Color(uiColor: .secondarySystemBackground) : ArcPalette.solidFieldSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isHighContrast ? Color.primary.opacity(0.20) : ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct FieldGuidanceRow: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ArcMiniIconBadge(systemImage: systemImage, tint: ArcPalette.glowSecondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct FieldPlanRequiredCard: View {
    var body: some View {
        ArcFeatureCard(accent: ArcPalette.glowPrimary) {
            ArcFeatureTitle(
                systemImage: "checklist",
                title: "No active field guide",
                subtitle: nil,
                accent: ArcPalette.glowPrimary
            )

            Text("Start or import a capture plan from Capture Plans to create a field-ready guide.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FieldProgressSection: View {
    let progress: Double
    let resolvedText: String
    let isHighContrast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Progress")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(progress.formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(ArcPalette.tint)
            }

            FieldProgressBar(progress: progress)

            Label(resolvedText, systemImage: "camera.metering.center.weighted.average")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .background(isHighContrast ? Color(uiColor: .systemBackground) : ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isHighContrast ? Color.primary.opacity(0.20) : ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct SafetyNetSheet: View {
    let addItems: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let items = [
        ("Wide shot", "Show where you are."),
        ("Close detail", "Capture one object, texture, sign, food, or piece of gear."),
        ("Human action", "Hands, feet, walking, packing, checking, eating, opening."),
        ("Natural sound", "Record 10 seconds without talking."),
        ("Honest reaction", "Say one line about what changed or mattered."),
        ("Leaving shot", "Show the transition away from this place.")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ArcCompactHeroHeader(
                        systemImage: "lifepreserver",
                        title: "Story Safety Net",
                        summary: "When you feel lost, capture this recovery set."
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section("Recovery Set") {
                    ForEach(items, id: \.0) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.0)
                                .font(.headline)
                            Text(item.1)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ArcSceneBackground())
            .navigationTitle("Safety Net")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        addItems()
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct FieldNoteEditorSheet: View {
    let item: ShootPlanItem
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var note: String

    init(item: ShootPlanItem, onSave: @escaping () -> Void) {
        self.item = item
        self.onSave = onSave
        _note = State(initialValue: item.fieldNote)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(item.title) {
                    TextField("Field note", text: $note, axis: .vertical)
                        .lineLimit(5, reservesSpace: true)
                }
            }
            .navigationTitle("Field Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        item.fieldNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FieldProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let clampedProgress = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.10))

                Capsule()
                    .fill(ArcPalette.tint)
                    .frame(width: proxy.size.width * clampedProgress)
            }
        }
        .frame(height: 12)
    }
}

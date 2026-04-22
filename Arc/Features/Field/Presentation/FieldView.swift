import SwiftData
import SwiftUI
import PhotosUI
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
    @State private var isConfirmingDelete = false
    @State private var isConfirmingFinish = false
    @State private var hasDismissedCompletionPrompt = false
    @State private var photoAttachmentError: String?

    init(
        location: ShootLocation,
        aiService: any AIServicing,
        locationEnricher: any LocationEnriching,
        referenceImageCache: any ReferenceImageCaching,
        locationEditorServices: LocationEditorServiceFactory
    ) {
        self.location = location
        self.aiService = aiService
        self.locationEnricher = locationEnricher
        self.referenceImageCache = referenceImageCache
        self.locationEditorServices = locationEditorServices
    }

    private var plan: ShootPlan? {
        guard let existingPlan = location.plan,
              existingPlan.isApprovedForField,
              existingPlan.completedAt == nil
        else {
            return nil
        }

        return existingPlan
    }

    private var planItems: [ShootPlanItem] {
        plan?.orderedItems ?? []
    }

    private var hasPlanItems: Bool {
        !planItems.isEmpty
    }

    private var completedCount: Int {
        plan?.capturedCount ?? 0
    }

    private var remainingCount: Int {
        max(planItems.count - completedCount, 0)
    }

    private var completionProgress: Double {
        plan?.completionProgress ?? 0
    }

    private var nextPendingItem: ShootPlanItem? {
        planItems.first(where: { !$0.isCaptured })
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
                    referenceStatus: referenceStatusText,
                    isHighContrast: isHighContrastMode
                )

                if hasPlanItems {
                    FieldProgressPanel(
                        completedCount: completedCount,
                        totalCount: planItems.count,
                        remainingCount: remainingCount,
                        progress: completionProgress,
                        nextPendingTitle: nextPendingItem?.title,
                        isHighContrast: isHighContrastMode
                    )
                }

                if let photoAttachmentError {
                    ArcInlineError(message: photoAttachmentError)
                        .padding(.horizontal, 2)
                }

                if hasPlanItems {
                    FieldChecklistCard(
                        items: planItems,
                        isHighContrast: isHighContrastMode,
                        toggleItem: toggleItemCompletion,
                        attachPhoto: attachPhoto,
                        removePhoto: removePhoto
                    )

                    if let plan {
                        FieldGuidanceCard(
                            location: location,
                            outputIntentTitle: plan.outputIntent.title,
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
        .navigationTitle("Field")
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
                .accessibilityLabel(isHighContrastMode ? "Disable high contrast field mode" : "Enable high contrast field mode")

                Button {
                    isPresentingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("Shoot info")

                Button {
                    isPresentingPlanEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit plan")
                .disabled(location.plan == nil)

                Menu {
                    Button {
                        isPresentingEditLocation = true
                    } label: {
                        Label("Edit Location", systemImage: "slider.horizontal.3")
                    }

                    Toggle(isOn: $isHighContrastMode) {
                        Label("High Contrast", systemImage: "sun.max")
                    }

                    Button {
                        isConfirmingFinish = true
                    } label: {
                        Label("Finish Shoot", systemImage: "checkmark.seal")
                    }
                    .disabled(!hasPlanItems)

                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete Shoot", systemImage: "trash")
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
        .confirmationDialog("Finish this shoot?", isPresented: $isConfirmingFinish, titleVisibility: .visible) {
            Button("Finish Shoot") {
                finishShoot()
            }

            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("The shoot will move to Completed. You can reopen it later.")
        }
        .confirmationDialog("Delete this shoot?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Shoot", role: .destructive) {
                deleteShoot()
            }

            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("This removes the location, plan, and checklist.")
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
        guard cacheStatus.totalImages > 0 else {
            return nil
        }

        return "References \(cacheStatus.cachedImages)/\(cacheStatus.totalImages)"
    }

    @ViewBuilder
    private var fieldActionBar: some View {
        if shouldShowCompletionPrompt {
            ArcBottomActionBar(
                title: "All shots captured",
                subtitle: "Finish to move this shoot to Completed.",
                primaryTitle: "Finish Shoot",
                primarySystemImage: "checkmark.seal",
                secondaryTitle: "Keep Open",
                secondarySystemImage: "xmark",
                usesSolidBackground: isHighContrastMode,
                primaryAction: { isConfirmingFinish = true },
                secondaryAction: { hasDismissedCompletionPrompt = true }
            )
        } else if nextPendingItem == nil {
            ArcBottomActionBar(
                title: "Checklist wrapped",
                subtitle: "\(completedCount)/\(planItems.count) captured.",
                primaryTitle: "Finish Shoot",
                primarySystemImage: "checkmark.seal",
                secondaryTitle: "Reset",
                secondarySystemImage: "arrow.counterclockwise",
                usesSolidBackground: isHighContrastMode,
                primaryAction: { isConfirmingFinish = true },
                secondaryAction: resetChecklist
            )
        } else {
            ArcBottomActionBar(
                title: nextPendingItem?.title ?? "Next shot",
                subtitle: "\(remainingCount) remaining • \(completionProgress.formatted(.percent.precision(.fractionLength(0)))) complete",
                primaryTitle: "Mark Next",
                primarySystemImage: "checkmark.circle.fill",
                secondaryTitle: "Reset",
                secondarySystemImage: "arrow.counterclockwise",
                usesSolidBackground: isHighContrastMode,
                primaryAction: completeNextItem,
                secondaryAction: resetChecklist
            )
        }
    }

    private func toggleItemCompletion(_ item: ShootPlanItem) {
        withAnimation(.easeInOut(duration: 0.18)) {
            item.isCaptured.toggle()
        }

        photoAttachmentError = nil
        hasDismissedCompletionPrompt = false
        playImpact(item.isCaptured ? .medium : .light)
        saveChanges()
    }

    private func completeNextItem() {
        guard let nextPendingItem else {
            return
        }

        toggleItemCompletion(nextPendingItem)
    }

    private func resetChecklist() {
        withAnimation(.easeInOut(duration: 0.18)) {
            for item in planItems {
                item.isCaptured = false
            }
        }

        photoAttachmentError = nil
        hasDismissedCompletionPrompt = false
        playImpact(.heavy)
        saveChanges()
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

    private func saveChanges() {
        try? modelContext.save()
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
    let referenceStatus: String?
    let isHighContrast: Bool

    var body: some View {
        ArcCompactHeroHeader(
            systemImage: "checklist.checked",
            title: locationName,
            summary: summary,
            tint: ArcPalette.tint
        )

        if let plan {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ArcStatusPill(plan.outputIntent.title, systemImage: "square.stack.3d.up")
                    ArcStatusPill(plan.shootWindowMode == .now ? "Now" : "Custom", systemImage: "calendar.badge.clock", tint: ArcPalette.glowPrimary)

                    if let referenceStatus {
                        ArcStatusPill(referenceStatus, systemImage: "arrow.down.circle", tint: ArcPalette.glowSecondary)
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
            return "No active checklist"
        }

        return "\(plan.outputIntent.title) • \(plan.shootWindowSummary)"
    }
}

private struct FieldProgressPanel: View {
    let completedCount: Int
    let totalCount: Int
    let remainingCount: Int
    let progress: Double
    let nextPendingTitle: String?
    let isHighContrast: Bool

    var body: some View {
        ArcDenseCard(accent: ArcPalette.tint) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    ArcMetricTile(title: "Complete", value: "\(completedCount)/\(totalCount)", systemImage: "checkmark.circle", accent: ArcPalette.tint)
                    ArcMetricTile(title: "Remaining", value: "\(remainingCount)", systemImage: "circle.dashed", accent: ArcPalette.glowPrimary)
                }

                VStack(spacing: 10) {
                    ArcMetricTile(title: "Complete", value: "\(completedCount)/\(totalCount)", systemImage: "checkmark.circle", accent: ArcPalette.tint)
                    ArcMetricTile(title: "Remaining", value: "\(remainingCount)", systemImage: "circle.dashed", accent: ArcPalette.glowPrimary)
                }
            }

            FieldProgressSection(
                progress: progress,
                nextPendingTitle: nextPendingTitle,
                isHighContrast: isHighContrast
            )
        }
    }
}

private struct FieldChecklistCard: View {
    let items: [ShootPlanItem]
    let isHighContrast: Bool
    let toggleItem: (ShootPlanItem) -> Void
    let attachPhoto: (PhotosPickerItem?, ShootPlanItem) -> Void
    let removePhoto: (ShootPlanItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ArcFeatureTitle(
                systemImage: "checklist",
                title: "Checklist",
                subtitle: nil,
                accent: ArcPalette.tint
            )

            VStack(spacing: 12) {
                ForEach(items) { item in
                    FieldChecklistRow(
                        item: item,
                        isHighContrast: isHighContrast,
                        toggleItem: {
                            toggleItem(item)
                        },
                        attachPhoto: { pickerItem in
                            attachPhoto(pickerItem, item)
                        },
                        removePhoto: {
                            removePhoto(item)
                        }
                    )
                }
            }
        }
        .padding(isHighContrast ? 18 : 20)
        .background(isHighContrast ? Color(uiColor: .secondarySystemBackground) : ArcPalette.solidFieldSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isHighContrast ? Color.primary.opacity(0.20) : ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct FieldGuidanceCard: View {
    let location: ShootLocation
    let outputIntentTitle: String
    let isHighContrast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ArcFeatureTitle(
                systemImage: "eye.fill",
                title: "Reminders",
                subtitle: nil,
                accent: ArcPalette.glowSecondary
            )

            FieldGuidanceRow(
                systemImage: "sparkles.rectangle.stack",
                title: "Stay on brief",
                subtitle: "Keep the \(outputIntentTitle) set coherent while shooting \(location.name)."
            )

            FieldGuidanceRow(
                systemImage: "mountain.2.fill",
                title: "Open wide first",
                subtitle: "Anchor \(location.name) before moving into details."
            )

            FieldGuidanceRow(
                systemImage: "sun.haze.fill",
                title: "Protect highlights",
                subtitle: "Bias a touch darker if the sky or reflections start to clip."
            )

            FieldGuidanceRow(
                systemImage: "rectangle.portrait.and.arrow.right",
                title: "Grab one vertical cutaway",
                subtitle: "Leave with one detail or motion frame for the edit."
            )
        }
        .padding(20)
        .background(isHighContrast ? Color(uiColor: .secondarySystemBackground) : ArcPalette.solidFieldSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isHighContrast ? Color.primary.opacity(0.20) : ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct FieldPlanRequiredCard: View {
    var body: some View {
        ArcFeatureCard(accent: ArcPalette.glowPrimary) {
            ArcFeatureTitle(
                systemImage: "checklist",
                title: "No active checklist",
                subtitle: nil,
                accent: ArcPalette.glowPrimary
            )

            Text("Start a new shoot from the Shoots screen to generate and approve a field checklist.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FieldProgressSection: View {
    let progress: Double
    let nextPendingTitle: String?
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

            Label(nextPendingTitle ?? "Checklist wrapped", systemImage: "camera.metering.center.weighted.average")
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

private struct FieldChecklistRow: View {
    let item: ShootPlanItem
    let isHighContrast: Bool
    let toggleItem: () -> Void
    let attachPhoto: (PhotosPickerItem?) -> Void
    let removePhoto: () -> Void

    private var thumbnailImage: UIImage? {
        guard let data = item.capturedPhotoData else {
            return nil
        }

        return UIImage(data: data)
    }

    var body: some View {
        let hasAttachedPhoto = item.capturedPhotoData != nil

        VStack(alignment: .leading, spacing: 12) {
            Button(action: toggleItem) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: item.isCaptured ? "checkmark.circle.fill" : "circle")
                        .font((isHighContrast ? Font.title2 : .title3).weight(.semibold))
                        .foregroundStyle(item.isCaptured ? ArcPalette.tint : .secondary)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(item.title)
                                .font(isHighContrast ? .title3.weight(.semibold) : .headline)
                                .foregroundStyle(.primary)

                            Spacer(minLength: 0)

                            Text(item.role)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(ArcPalette.tint.opacity(0.14), in: Capsule())
                                .foregroundStyle(ArcPalette.tint)
                        }

                        Text(item.guidance)
                            .font(isHighContrast ? .body : .subheadline)
                            .foregroundStyle(isHighContrast ? .primary : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .buttonStyle(.plain)

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

            HStack(spacing: 10) {
                PhotosPicker(
                    selection: Binding<PhotosPickerItem?>(
                        get: { nil },
                        set: { attachPhoto($0) }
                    ),
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label(hasAttachedPhoto ? "Replace Snap" : "Add Snap", systemImage: "camera.fill")
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(isHighContrast ? 20 : 18)
        .background(isHighContrast ? Color(uiColor: .systemBackground) : ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(item.isCaptured ? ArcPalette.tint.opacity(isHighContrast ? 0.75 : 0.45) : (isHighContrast ? Color.primary.opacity(0.20) : ArcPalette.surfaceStroke), lineWidth: isHighContrast ? 1.5 : 1)
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

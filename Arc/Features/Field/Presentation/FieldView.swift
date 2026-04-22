import SwiftData
import SwiftUI

struct FieldView: View {
    let location: ShootLocation
    let aiService: any AIServicing
    let locationEnricher: any LocationEnriching
    let referenceImageCache: any ReferenceImageCaching
    let locationEditorServices: LocationEditorServiceFactory

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var cacheStatus = ReferenceImageCacheResult(totalImages: 0, cachedImages: 0)
    @State private var isPresentingInfo = false
    @State private var isPresentingPlanEditor = false
    @State private var isPresentingEditLocation = false
    @State private var isConfirmingDelete = false
    @State private var isConfirmingFinish = false
    @State private var hasDismissedCompletionPrompt = false

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
                    referenceStatus: referenceStatusText
                )

                if hasPlanItems {
                    FieldProgressPanel(
                        completedCount: completedCount,
                        totalCount: planItems.count,
                        remainingCount: remainingCount,
                        progress: completionProgress,
                        nextPendingTitle: nextPendingItem?.title
                    )
                }

                if hasPlanItems {
                    FieldChecklistCard(
                        items: planItems,
                        toggleItem: toggleItemCompletion
                    )

                    if let plan {
                        FieldGuidanceCard(
                            location: location,
                            outputIntentTitle: plan.outputIntent.title
                        )
                    }
                } else {
                    FieldPlanRequiredCard()
                }
            }
            .padding(16)
            .padding(.bottom, hasPlanItems ? 112 : 0)
        }
        .background(ArcSceneBackground())
        .safeAreaInset(edge: .bottom) {
            if hasPlanItems {
                fieldActionBar
            }
        }
        .navigationTitle("Field")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
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
                primaryAction: completeNextItem,
                secondaryAction: resetChecklist
            )
        }
    }

    private func toggleItemCompletion(_ item: ShootPlanItem) {
        withAnimation(.easeInOut(duration: 0.18)) {
            item.isCaptured.toggle()
        }

        hasDismissedCompletionPrompt = false
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

        hasDismissedCompletionPrompt = false
        saveChanges()
    }

    private func finishShoot() {
        guard let plan else {
            return
        }

        plan.completedAt = Date()
        saveChanges()
        dismiss()
    }

    private func deleteShoot() {
        modelContext.delete(location)
        saveChanges()
        dismiss()
    }

    private func saveChanges() {
        try? modelContext.save()
    }
}

private struct FieldExecutionHeader: View {
    let locationName: String
    let plan: ShootPlan?
    let referenceStatus: String?

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
                nextPendingTitle: nextPendingTitle
            )
        }
    }
}

private struct FieldChecklistCard: View {
    let items: [ShootPlanItem]
    let toggleItem: (ShootPlanItem) -> Void

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
                    Button {
                        toggleItem(item)
                    } label: {
                        FieldChecklistRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(ArcPalette.solidFieldSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct FieldGuidanceCard: View {
    let location: ShootLocation
    let outputIntentTitle: String

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
        .background(ArcPalette.solidFieldSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
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
        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct FieldChecklistRow: View {
    let item: ShootPlanItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.isCaptured ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(item.isCaptured ? ArcPalette.tint : .secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(item.isCaptured ? ArcPalette.tint.opacity(0.45) : ArcPalette.surfaceStroke, lineWidth: 1)
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

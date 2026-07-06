import SwiftData
import SwiftUI

struct PlanEditorSheet: View {
    let location: ShootLocation
    let aiService: any AIServicing
    let locationEnricher: any LocationEnriching
    let referenceImageCache: any ReferenceImageCaching

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: PlanViewModel
    @State private var selectedSection: PlanEditorSection = .checklist
    @State private var isRefreshingContext = false
    @State private var contextRefreshError: String?
    @State private var editingItem: ShootPlanItem?
    @State private var pendingRegenerationDrafts: [ShootDraftItem] = []
    @State private var pendingRegenerationRawResponse = ""
    @State private var isApplyingRegeneration = false
    @State private var editTitle = ""
    @State private var editRole = ""
    @State private var editGuidance = ""

    init(
        location: ShootLocation,
        aiService: any AIServicing,
        locationEnricher: any LocationEnriching,
        referenceImageCache: any ReferenceImageCaching
    ) {
        self.location = location
        self.aiService = aiService
        self.locationEnricher = locationEnricher
        self.referenceImageCache = referenceImageCache
        _viewModel = State(
            initialValue: PlanViewModel(
                aiService: aiService,
                existingPlan: location.plan,
                referenceImageCache: referenceImageCache
            )
        )
    }

    private var planItems: [ShootPlanItem] {
        location.plan?.orderedItems ?? []
    }

    private var visibleSections: [PlanEditorSection] {
        location.plan?.source == .importedText ? [.checklist] : PlanEditorSection.allCases
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ArcCompactHeroHeader(
                        systemImage: "slider.horizontal.3",
                        title: "Edit Capture Plan",
                        summary: location.name
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    Picker("Plan section", selection: $selectedSection) {
                        ForEach(visibleSections) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                currentPlanSection

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        ArcFeatureCard(accent: .red) {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }

            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(ArcSceneBackground())
            .navigationTitle("Capture Plan")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !visibleSections.contains(selectedSection) {
                    selectedSection = .checklist
                }
            }
            .onChange(of: viewModel.shootStartTime) { _, _ in
                viewModel.ensureDefaultWindowTimes()
                clearPendingRegeneration()
            }
            .onChange(of: viewModel.shootEndTime) { _, _ in
                clearPendingRegeneration()
            }
            .onChange(of: viewModel.shootDate) { _, _ in
                clearPendingRegeneration()
            }
            .onChange(of: viewModel.shootWindowMode) { _, _ in
                clearPendingRegeneration()
            }
            .onChange(of: viewModel.outputIntent) { _, _ in
                viewModel.applyOutputDefaults()
                clearPendingRegeneration()
            }
            .onChange(of: viewModel.captureMedium) { _, _ in
                clearPendingRegeneration()
            }
            .onChange(of: viewModel.targetPlatform) { _, _ in
                clearPendingRegeneration()
            }
            .onChange(of: viewModel.stylePreset) { _, _ in
                clearPendingRegeneration()
            }
            .onChange(of: viewModel.notes) { _, _ in
                clearPendingRegeneration()
            }
            .task(id: location.enrichmentJSON) {
                viewModel.refreshReferenceCacheStatus(for: location)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveExistingPlanMetadata()
                        dismiss()
                    }
                }
            }
            .sheet(item: $editingItem) { _ in
                editItemSheet
            }
        }
    }

    @ViewBuilder
    private var currentPlanSection: some View {
        switch selectedSection {
        case .checklist:
            checklistSection
        case .regenerate:
            regenerateSection
        case .context:
            contextSection
        }
    }

    private var checklistSection: some View {
        Section {
            ArcFeatureCard(accent: ArcPalette.glowPrimary) {
                ArcFeatureTitle(
                    systemImage: "checklist",
                    title: "Shot List",
                    subtitle: planItems.isEmpty ? "No items are saved yet." : "\(planItems.count) live items",
                    accent: ArcPalette.glowPrimary
                )

                if planItems.isEmpty {
                    Text("Regenerate the plan to create a field-ready shot list.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ShootPlanItemList(
                        items: planItems,
                        onEdit: beginEditing,
                        onDelete: deleteItem
                    )
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var regenerateSection: some View {
        Section {
            ArcFeatureCard(accent: ArcPalette.tint) {
                ArcFeatureTitle(
                    systemImage: "sparkles.rectangle.stack",
                    title: "Regenerate",
                    subtitle: "\(viewModel.outputIntent.defaultShotCount) shots. \(viewModel.captureMedium.title). \(viewModel.targetPlatform.title)."
                )

                ShootPlanningControls(
                    outputIntent: $viewModel.outputIntent,
                    captureMedium: $viewModel.captureMedium,
                    targetPlatform: $viewModel.targetPlatform,
                    stylePreset: $viewModel.stylePreset,
                    shootWindowMode: $viewModel.shootWindowMode,
                    shootDate: $viewModel.shootDate,
                    shootStartTime: $viewModel.shootStartTime,
                    shootEndTime: $viewModel.shootEndTime
                )

                ArcInlinePanel {
                    ArcFeatureTitle(
                        systemImage: "note.text",
                        title: "Notes",
                        subtitle: "Saved when you tap Done or regenerate.",
                        accent: ArcPalette.glowSecondary
                    )

                    ShootNotesEditor(notes: $viewModel.notes)
                }

                Button {
                    Task {
                        await generateRegenerationPreview()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(viewModel.isLoading ? "Generating Preview..." : "Preview New Shot List")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(viewModel.isLoading || isApplyingRegeneration)

                if !pendingRegenerationDrafts.isEmpty {
                    ArcInlinePanel {
                        ArcFeatureTitle(
                            systemImage: "doc.text.magnifyingglass",
                            title: "Preview Ready",
                            subtitle: "Current shot list stays unchanged until you replace it.",
                            accent: ArcPalette.glowSecondary
                        )

                        ShootDraftPreviewList(items: pendingRegenerationDrafts)

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                discardPreviewButton
                                replaceShotListButton
                            }

                            VStack(spacing: 10) {
                                discardPreviewButton
                                replaceShotListButton
                            }
                        }
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var contextSection: some View {
        Section {
            ArcFeatureCard(accent: contextAccent) {
                ArcFeatureTitle(
                    systemImage: hasCachedContext ? "checkmark.circle.fill" : "map.circle.fill",
                    title: hasCachedContext ? "Context ready" : "Fetch context",
                    subtitle: contextSubtitle,
                    accent: contextAccent
                )

                if let contextRefreshError {
                    ArcInlineError(message: contextRefreshError)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        refreshContextButton
                        inspectContextLink
                    }

                    VStack(spacing: 10) {
                        refreshContextButton
                        inspectContextLink
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var refreshContextButton: some View {
        Button {
            Task {
                await refreshContext()
            }
        } label: {
            HStack(spacing: 8) {
                if isRefreshingContext {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(isRefreshingContext ? "Refreshing..." : (hasCachedContext ? "Refresh Context" : "Fetch Context"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .disabled(isRefreshingContext || viewModel.isLoading)
    }

    private var discardPreviewButton: some View {
        Button {
            clearPendingRegeneration()
        } label: {
            Label("Discard Preview", systemImage: "xmark")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .disabled(viewModel.isLoading || isApplyingRegeneration)
    }

    private var replaceShotListButton: some View {
        Button {
            Task {
                await applyRegenerationPreview()
            }
        } label: {
            HStack(spacing: 8) {
                if isApplyingRegeneration {
                    ProgressView()
                        .controlSize(.small)
                }

                Label("Replace Shot List", systemImage: "checkmark.circle")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .disabled(viewModel.isLoading || isApplyingRegeneration || pendingRegenerationDrafts.isEmpty)
    }

    @ViewBuilder
    private var inspectContextLink: some View {
        if hasCachedContext {
            NavigationLink {
                LocationContextView(location: location, locationEnricher: locationEnricher)
            } label: {
                Label("Inspect", systemImage: "doc.text.magnifyingglass")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
    }

    private var editItemSheet: some View {
        NavigationStack {
            Form {
                Section("Shot") {
                    TextField("Title", text: $editTitle)
                    TextField("Role", text: $editRole)
                    TextField("Guidance", text: $editGuidance, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
            }
            .navigationTitle("Edit Shot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        editingItem = nil
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveItemEdits()
                    }
                }
            }
        }
    }

    private var hasCachedContext: Bool {
        !location.enrichmentJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var contextAccent: Color {
        hasCachedContext ? ArcPalette.tint : ArcPalette.glowPrimary
    }

    private var contextSubtitle: String {
        if let lastEnrichedAt = location.lastEnrichedAt, hasCachedContext {
            return "Cached \(lastEnrichedAt.formatted(date: .abbreviated, time: .shortened)). Regeneration will use landmarks, weather, references, and sun/moon timing."
        }

        return "Fetch landmarks, weather, references, and sun/moon timing before regenerating this shot list."
    }

    private func refreshContext() async {
        guard !isRefreshingContext else {
            return
        }

        guard let shootWindow = viewModel.shootWindowInterval else {
            contextRefreshError = "End time must be after start time."
            return
        }

        isRefreshingContext = true
        contextRefreshError = nil
        defer { isRefreshingContext = false }

        let bundle = await locationEnricher.enrich(location: location, shootWindow: shootWindow)

        do {
            let formattedJSON = try bundle.formattedJSONString()
            location.enrichmentJSON = formattedJSON
            location.lastEnrichedAt = bundle.generatedAt
            try modelContext.save()
            clearPendingRegeneration()
            viewModel.refreshReferenceCacheStatus(for: location)
        } catch {
            contextRefreshError = error.localizedDescription
        }
    }

    private func generateRegenerationPreview() async {
        guard let generationResult = await viewModel.generatePreview(for: location) else {
            return
        }

        pendingRegenerationDrafts = generationResult.drafts.map(ShootDraftItem.init)
        pendingRegenerationRawResponse = generationResult.rawResponse
    }

    private func applyRegenerationPreview() async {
        guard !pendingRegenerationDrafts.isEmpty else {
            return
        }

        isApplyingRegeneration = true
        defer { isApplyingRegeneration = false }

        let didApply = await viewModel.applyGeneratedPlan(
            rawResponse: pendingRegenerationRawResponse,
            drafts: pendingRegenerationDrafts.map(\.plannedShotDraft),
            for: location,
            modelContext: modelContext,
            approve: true
        )

        if didApply {
            clearPendingRegeneration()
            selectedSection = .checklist
        }
    }

    private func clearPendingRegeneration() {
        pendingRegenerationDrafts = []
        pendingRegenerationRawResponse = ""
    }

    private func saveExistingPlanMetadata() {
        guard let plan = location.plan else {
            return
        }

        plan.notes = viewModel.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.outputIntentRawValue = viewModel.outputIntent.rawValue
        plan.captureMediumRawValue = viewModel.captureMedium.rawValue
        plan.targetPlatformRawValue = viewModel.targetPlatform.rawValue
        plan.stylePresetRawValue = viewModel.stylePreset.rawValue
        plan.shootWindowModeRawValue = viewModel.shootWindowMode.rawValue
        plan.shootWindowSummary = viewModel.shootWindowSummary
        plan.shootDate = viewModel.shootDate
        plan.shootStartTime = viewModel.shootStartTime
        plan.shootEndTime = viewModel.shootEndTime
        plan.isApprovedForField = true
        plan.completedAt = nil
        try? modelContext.save()
    }

    private func beginEditing(_ item: ShootPlanItem) {
        editTitle = item.title
        editRole = item.role
        editGuidance = item.guidance
        editingItem = item
    }

    private func saveItemEdits() {
        guard let currentItem = editingItem else {
            return
        }

        let cleanTitle = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRole = editRole.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGuidance = editGuidance.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty, !cleanGuidance.isEmpty else {
            return
        }

        currentItem.title = cleanTitle
        currentItem.role = cleanRole.isEmpty ? "Support" : cleanRole
        currentItem.guidance = cleanGuidance
        location.plan?.isApprovedForField = true
        location.plan?.completedAt = nil
        try? modelContext.save()
        editingItem = nil
    }

    private func deleteItem(_ item: ShootPlanItem) {
        guard let plan = location.plan else {
            return
        }

        let remainingItems = plan.orderedItems.filter { $0.id != item.id }
        for (index, remainingItem) in remainingItems.enumerated() {
            remainingItem.orderIndex = index
        }

        plan.items.removeAll { $0.id == item.id }
        plan.isApprovedForField = !plan.items.isEmpty
        plan.completedAt = nil
        modelContext.delete(item)
        try? modelContext.save()
    }
}

private enum PlanEditorSection: String, CaseIterable, Identifiable {
    case checklist
    case regenerate
    case context

    var id: String { rawValue }

    var title: String {
        switch self {
        case .checklist:
            return "Shot List"
        case .regenerate:
            return "Regenerate"
        case .context:
            return "Context"
        }
    }
}

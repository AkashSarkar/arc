import SwiftData
import SwiftUI
import UIKit

struct ImportPlanFlowView: View {
    let aiService: any AIServicing
    let locationEditorServices: LocationEditorServiceFactory
    let onCommit: (ShootLocation) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var locationViewModel: LocationEditorViewModel
    @State private var step: ImportPlanStep = .location
    @State private var locationDraft: LocationDraftValue?
    @State private var projectTitle: String
    @State private var planText: String
    @State private var document: ArcPlanDocument?
    @State private var draft: FieldGuideDraft
    @State private var parseNotice: String?
    @State private var isImprovingWithAI = false
    @State private var isCommitting = false
    @State private var didPrepareInitialDraft = false
    @State private var errorMessage: String?
    @State private var foundationPlanService = FoundationModelsPlanService()

    init(
        aiService: any AIServicing,
        locationEditorServices: LocationEditorServiceFactory,
        initialText: String = "",
        initialDocument: ArcPlanDocument? = nil,
        onCommit: @escaping (ShootLocation) -> Void
    ) {
        self.aiService = aiService
        self.locationEditorServices = locationEditorServices
        self.onCommit = onCommit
        _locationViewModel = State(
            initialValue: LocationEditorViewModel(
                currentLocationService: locationEditorServices.makeCurrentLocationService(),
                searchService: locationEditorServices.makeSearchService(),
                reverseGeocodingService: locationEditorServices.makeReverseGeocodingService()
            )
        )
        _projectTitle = State(initialValue: initialDocument?.trip.title ?? "")
        _planText = State(initialValue: initialDocument?.sourceText ?? initialText)
        _document = State(initialValue: initialDocument)
        _draft = State(initialValue: initialDocument?.fieldGuideDraft ?? .empty)
    }

    private var effectiveProjectTitle: String {
        let cleanTitle = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTitle.isEmpty {
            return cleanTitle
        }

        let draftTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return draftTitle.isEmpty ? "Imported Plan" : draftTitle
    }

    private var canCreatePlan: Bool {
        locationDraft != nil
            && !effectiveProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !planText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.itemCount > 0
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .location:
                    locationStepScreen
                case .plan:
                    importForm
                }
            }
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isImprovingWithAI || isCommitting)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isImprovingWithAI || isCommitting)
                }
            }
            .task {
                foundationPlanService.prewarm()
                prepareInitialDraftIfNeeded()
            }
        }
    }

    private var locationStepScreen: some View {
        ShootSpotPickerView(
            viewModel: locationViewModel,
            systemImage: "location.viewfinder",
            title: "Choose Import Spot",
            subtitle: "Pick the real starting spot for this imported plan.",
            badges: [ArcHeroBadge(label: "Required", systemImage: "mappin.and.ellipse")],
            primaryButtonTitle: "Continue",
            primarySystemImage: "arrow.right",
            primaryAction: continueFromLocation
        )
    }

    private var importForm: some View {
        Form {
            setupSection
            draftSection

            if let parseNotice {
                Section {
                    ArcInlinePanel {
                        Label(parseNotice, systemImage: "checkmark.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            if let errorMessage {
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ArcBottomActionBar(
                title: draft.itemCount > 0 ? "\(draft.stages.count) stages ready" : "Paste your Apple Notes plan",
                subtitle: draft.itemCount > 0 ? "\(draft.itemCount) field items" : "Arc will structure it locally.",
                primaryTitle: "Start Field Guide",
                primarySystemImage: "checkmark.circle",
                isPrimaryLoading: isCommitting,
                isPrimaryDisabled: !canCreatePlan || isImprovingWithAI || isCommitting,
                secondaryTitle: "Improve with AI",
                secondarySystemImage: "sparkles",
                isSecondaryDisabled: !canImproveWithAI || isImprovingWithAI || isCommitting,
                primaryAction: commitImportedPlan,
                secondaryAction: {
                    Task { await parseWithBestTier(allowCloud: true) }
                }
            )
        }
        .onChange(of: planText) { _, _ in
            rebuildLocalDraft()
        }
        .onChange(of: projectTitle) { _, _ in
            rebuildLocalDraft()
        }
    }

    private var setupSection: some View {
        Section {
            ArcFeatureCard(accent: ArcPalette.tint) {
                ArcFeatureTitle(
                    systemImage: "square.and.arrow.down",
                    title: "Import Existing Plan",
                    subtitle: "Paste or share a plan. Arc parses it locally first; smart parsing is optional."
                )

                selectedLocationCard

                TextField("Project title", text: $projectTitle)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                ZStack(alignment: .topLeading) {
                    if planText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Paste your trip plan, shot list, itinerary, or content notes.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $planText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 190)
                        .padding(12)
                        .accessibilityLabel("Imported plan text")
                }
                .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        pasteButton
                        rebuildButton
                        smartParseButton
                        templateButton
                    }

                    VStack(spacing: 10) {
                        pasteButton
                        rebuildButton
                        smartParseButton
                        templateButton
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var selectedLocationCard: some View {
        ArcInlinePanel {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(ArcPalette.tint)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(locationDraft?.name ?? "No spot selected")
                        .font(.subheadline.weight(.semibold))
                    Text(locationDraft.map { "\($0.coordinate.latitude.formatted(.number.precision(.fractionLength(5)))), \($0.coordinate.longitude.formatted(.number.precision(.fractionLength(5))))" } ?? "A real spot is required before commit.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button("Change") {
                    step = .location
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var draftSection: some View {
        Section {
            ArcFeatureCard(accent: ArcPalette.glowSecondary) {
                ArcFeatureTitle(
                    systemImage: "rectangle.stack",
                    title: "Field Stages",
                    subtitle: draft.itemCount == 0 ? "Paste a plan to create a draft." : "\(draft.stages.count) stages and \(draft.itemCount) items.",
                    accent: ArcPalette.glowSecondary
                )

                if !draft.storySummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(draft.storySummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if isImprovingWithAI {
                    ArcInlinePanel {
                        Label("Parsing smart draft...", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                        ProgressView()
                    }
                }

                if draft.stages.isEmpty {
                    Text("Your staged guide will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach($draft.stages) { $stage in
                        ImportedStageEditor(
                            stage: $stage,
                            deleteStage: { deleteStage(stage.id) },
                            addItem: { addItem(to: stage.id) },
                            deleteItem: { itemID in deleteItem(itemID, from: stage.id) }
                        )
                    }
                }

                Button {
                    addStage()
                } label: {
                    Label("Add Stage", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 120, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var pasteButton: some View {
        PasteButton(payloadType: String.self) { values in
            guard let value = values.first?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                errorMessage = "Clipboard does not contain text."
                return
            }

            planText = value
            errorMessage = nil
        }
        .buttonStyle(.glass)
    }

    private var rebuildButton: some View {
        Button {
            rebuildLocalDraft()
        } label: {
            Label("Basic Parse", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .disabled(planText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var smartParseButton: some View {
        Button {
            Task { await parseWithBestTier(allowCloud: false) }
        } label: {
            Label("Smart Parse", systemImage: "brain")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .disabled(!canImproveWithAI || isImprovingWithAI || isCommitting)
    }

    private var templateButton: some View {
        Button {
            UIPasteboard.general.string = ArcPlanTemplate.text
            parseNotice = "ChatGPT template copied."
        } label: {
            Label("Template", systemImage: "doc.on.doc")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
    }

    private var canImproveWithAI: Bool {
        !effectiveProjectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !planText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func continueFromLocation() {
        guard let draft = locationViewModel.validatedDraft() else {
            return
        }

        locationDraft = draft
        if projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            projectTitle = draft.name
        }
        errorMessage = nil
        step = .plan
    }

    private func prepareInitialDraftIfNeeded() {
        guard !didPrepareInitialDraft else {
            return
        }

        didPrepareInitialDraft = true

        if let document {
            apply(document: document, notice: "Opened Arc guide document.")
        } else if !planText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rebuildLocalDraft()
        }
    }

    private func rebuildLocalDraft() {
        let text = planText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            draft = .empty
            document = nil
            parseNotice = nil
            return
        }

        let parsedDocument = ImportedPlanParser.parseDocument(title: effectiveProjectTitle, text: text)
        apply(document: parsedDocument, notice: "Parsed with basic rules.")
    }

    private func parseWithBestTier(allowCloud: Bool) async {
        let text = planText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }

        isImprovingWithAI = true
        errorMessage = nil
        defer { isImprovingWithAI = false }

        let fallback = ImportedPlanParser.parseDocument(title: effectiveProjectTitle, text: text)

        if allowCloud {
            do {
                let cloudDocument = try await ImportedPlanGenerator(aiService: aiService).improveDocument(title: effectiveProjectTitle, text: text)
                apply(document: cloudDocument, notice: "Parsed with optional cloud cleanup.")
                return
            } catch {
                parseNotice = "Cloud cleanup failed — falling back."
            }
        }

        switch await foundationPlanService.parse(title: effectiveProjectTitle, text: text, fallback: fallback) {
        case .parsed(let document):
            let notice = document.generator.contains("import-t1") ? "Parsed on-device." : "Parsed with basic rules."
            apply(document: document, notice: notice)
        case .unavailable(let notice):
            apply(document: fallback, notice: notice ?? "Parsed with basic rules.")
        }
    }

    private func apply(document: ArcPlanDocument, notice: String?) {
        var updatedDocument = document
        let title = effectiveProjectTitle
        if updatedDocument.trip.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || updatedDocument.trip.title == "Imported Plan" {
            updatedDocument.trip.title = title
        }

        self.document = updatedDocument
        self.draft = updatedDocument.fieldGuideDraft
        self.parseNotice = notice
        errorMessage = nil
    }

    private func addStage() {
        draft.stages.append(
            FieldGuideStageDraft(
                title: "New Stage",
                goal: "Capture the beat clearly enough to carry the edit.",
                items: [
                    FieldGuideItemDraft(
                        title: "Must-capture item",
                        guidance: "Describe what you need to capture here."
                    )
                ]
            )
        )
    }

    private func deleteStage(_ stageID: UUID) {
        draft.stages.removeAll { $0.id == stageID }
    }

    private func addItem(to stageID: UUID) {
        guard let stageIndex = draft.stages.firstIndex(where: { $0.id == stageID }) else {
            return
        }

        draft.stages[stageIndex].items.append(
            FieldGuideItemDraft(
                title: "New item",
                guidance: "Describe what to capture."
            )
        )
    }

    private func deleteItem(_ itemID: UUID, from stageID: UUID) {
        guard let stageIndex = draft.stages.firstIndex(where: { $0.id == stageID }) else {
            return
        }

        draft.stages[stageIndex].items.removeAll { $0.id == itemID }
    }

    private func commitImportedPlan() {
        guard canCreatePlan, let locationDraft else {
            errorMessage = "Pick a real spot, add a title, paste a plan, and keep at least one field item."
            return
        }

        let text = planText.trimmingCharacters(in: .whitespacesAndNewlines)
        var commitDocument = document ?? ImportedPlanParser.parseDocument(title: effectiveProjectTitle, text: text)
        commitDocument.trip.title = effectiveProjectTitle
        commitDocument.sourceText = commitDocument.sourceText.isEmpty ? text : commitDocument.sourceText

        isCommitting = true
        errorMessage = nil
        defer { isCommitting = false }

        let location = ShootLocation(
            name: locationDraft.name,
            latitude: locationDraft.coordinate.latitude,
            longitude: locationDraft.coordinate.longitude
        )
        let plan = ShootPlan(
            notes: text,
            rawResponse: encodedDocumentJSON(commitDocument) ?? text,
            source: .importedText,
            importedPlanText: commitDocument.sourceText.isEmpty ? text : commitDocument.sourceText,
            storySummary: draft.storySummary,
            currentStageOrderIndex: 0,
            outputIntent: .fullTravelVlog,
            captureMedium: .hybrid,
            targetPlatform: .youtube,
            stylePreset: .natural,
            shootWindowMode: .custom,
            shootWindowSummary: "Imported field guide.",
            isApprovedForField: true,
            approvedAt: Date(),
            location: location
        )

        location.plan = plan
        modelContext.insert(location)
        modelContext.insert(plan)

        var globalOrderIndex = 0
        for (stageIndex, stage) in draft.stages.enumerated() {
            let stageTitle = stage.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Stage \(stageIndex + 1)" : stage.title
            let stageGoal = stage.goal.trimmingCharacters(in: .whitespacesAndNewlines)

            for item in stage.items where !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let planItem = ShootPlanItem(
                    orderIndex: globalOrderIndex,
                    title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    role: item.kind.title,
                    guidance: item.guidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Capture this clearly enough to use in the edit." : item.guidance,
                    stageTitle: stageTitle,
                    stageOrderIndex: stageIndex,
                    stageGoal: stageGoal,
                    kind: item.kind,
                    priority: item.priority,
                    isBeforeLeaving: item.isBeforeLeaving,
                    plan: plan
                )
                modelContext.insert(planItem)
                plan.items.append(planItem)
                globalOrderIndex += 1
            }
        }

        do {
            try modelContext.save()
            onCommit(location)
            dismiss()
        } catch {
            modelContext.delete(location)
            errorMessage = error.localizedDescription
        }
    }

    private func encodedDocumentJSON(_ document: ArcPlanDocument) -> String? {
        guard let data = try? ArcDocumentCodec.encode(document) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}

private enum ImportPlanStep {
    case location
    case plan

    var title: String {
        switch self {
        case .location:
            return "Choose Spot"
        case .plan:
            return "Import Plan"
        }
    }
}

private enum ArcPlanTemplate {
    static let text = """
    You are formatting a video shoot plan for the Arc app. Output ONLY the plan in
    exactly this markdown structure — no intro, no outro, no explanations, no prose
    outside the structure.

    Structure (follow it exactly):

    # <Trip title>

    ## Day 1: <day theme>

    ### Stop: <place name>
    <Google Maps link for this exact place, on its own line>

    <Stage name>:
    - <shot title> - <one line of how to shoot it> (must)
    - voice: <line to say to camera> - <delivery note> (must)
    - sound: <audio to record> - <length and quality note> (optional)
    - transition: <movement shot> - <how to shoot it>
    - note: <reminder that is not a shot>

    Before you leave:
    - <final must-have before departing> (must)

    Rules:
    1. Every stop MUST have a Google Maps link on its own line directly under the
       "### Stop:" heading.
    2. Every stop has 2-5 stages. Every stage has 3-7 bullet items.
    3. Every item is one bullet: "title - guidance". Never multi-line.
    4. Mark truly essential items "(must)" and skippable ones "(optional)".
       3-6 musts per stop, no more.
    5. Every stop includes at least one voice: item, one sound: item, and one
       transition: item somewhere in its stages.
    6. Every stop ends with a "Before you leave:" block of 1-3 items.
    7. Stage names are short (2-5 words) and always end with a colon.
    8. No text anywhere outside this structure. No tables, no blockquotes,
       no nested bullets.

    Here is my trip plan / idea dump — convert it:

    <PASTE TRIP NOTES HERE>
    """
}

private struct ImportedStageEditor: View {
    @Binding var stage: FieldGuideStageDraft
    let deleteStage: () -> Void
    let addItem: () -> Void
    let deleteItem: (UUID) -> Void

    var body: some View {
        ArcInlinePanel {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Stage title", text: $stage.title)
                        .font(.headline)

                    TextField("Stage goal", text: $stage.goal, axis: .vertical)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                }

                Button(role: .destructive, action: deleteStage) {
                    Image(systemName: "trash")
                        .frame(width: 36, height: 28)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Delete stage")
            }

            if !stage.sourceGeoAnchor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label(stage.sourceGeoAnchor, systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            ForEach($stage.items) { $item in
                ImportedItemEditor(item: $item, deleteItem: { deleteItem(item.id) })
            }

            Button(action: addItem) {
                Label("Add Item", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
    }
}

private struct ImportedItemEditor: View {
    @Binding var item: FieldGuideItemDraft
    let deleteItem: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                TextField("Item title", text: $item.title)
                    .font(.subheadline.weight(.semibold))

                Button(role: .destructive, action: deleteItem) {
                    Image(systemName: "minus.circle")
                        .frame(width: 34, height: 28)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Delete item")
            }

            TextField("Guidance", text: $item.guidance, axis: .vertical)
                .lineLimit(2, reservesSpace: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Picker("Kind", selection: $item.kind) {
                        ForEach(FieldGuideItemKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Priority", selection: $item.priority) {
                        ForEach(FieldGuidePriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Before leaving", isOn: $item.isBeforeLeaving)
                        .toggleStyle(.switch)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Picker("Kind", selection: $item.kind) {
                        ForEach(FieldGuideItemKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Priority", selection: $item.priority) {
                        ForEach(FieldGuidePriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Before leaving", isOn: $item.isBeforeLeaving)
                        .toggleStyle(.switch)
                }
            }

            if item.isSynthetic {
                ArcStatusPill("Synthetic", systemImage: "wand.and.stars", tint: ArcPalette.glowSecondary)
            }
        }
        .padding(12)
        .background(ArcPalette.solidFieldSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

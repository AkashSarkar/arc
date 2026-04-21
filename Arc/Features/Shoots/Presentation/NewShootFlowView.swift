import SwiftData
import SwiftUI

struct NewShootFlowView: View {
    let aiService: any AIServicing
    let locationEnricher: any LocationEnriching
    let referenceImageCache: any ReferenceImageCaching
    let onCommit: (ShootLocation) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var locationViewModel: LocationEditorViewModel
    @State private var step: NewShootStep = .location
    @State private var locationDraft: LocationDraftValue?
    @State private var outputIntent: OutputIntent = .instagramCarousel
    @State private var shootWindowMode: ShootWindowMode = .now
    @State private var shootDate: Date = Date()
    @State private var shootStartTime: Date = Date()
    @State private var shootEndTime: Date = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    @State private var notes = ""
    @State private var rawResponse = ""
    @State private var generatedEnrichmentJSON = ""
    @State private var generatedLastEnrichedAt: Date?
    @State private var draftItems: [ShootDraftItem] = []
    @State private var errorMessage: String?
    @State private var isFetchingContext = false
    @State private var isGenerating = false
    @State private var isCommitting = false
    @State private var editingDraft: ShootDraftItem?
    @State private var editTitle = ""
    @State private var editRole = ""
    @State private var editGuidance = ""

    private let generator: ShotListGenerator
    private let calendar = Calendar.current

    init(
        aiService: any AIServicing,
        locationEnricher: any LocationEnriching,
        referenceImageCache: any ReferenceImageCaching,
        locationEditorServices: LocationEditorServiceFactory,
        onCommit: @escaping (ShootLocation) -> Void
    ) {
        self.aiService = aiService
        self.locationEnricher = locationEnricher
        self.referenceImageCache = referenceImageCache
        self.onCommit = onCommit
        self.generator = ShotListGenerator(aiService: aiService)
        _locationViewModel = State(
            initialValue: LocationEditorViewModel(
                currentLocationService: locationEditorServices.makeCurrentLocationService(),
                searchService: locationEditorServices.makeSearchService(),
                reverseGeocodingService: locationEditorServices.makeReverseGeocodingService()
            )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if step == .location {
                    locationStepScreen
                } else {
                    wizardForm
                }
            }
            .navigationTitle("New Shoot")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isFetchingContext || isGenerating || isCommitting)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isFetchingContext || isGenerating || isCommitting)
                }
            }
            .sheet(item: $editingDraft) { _ in
                draftEditSheet
            }
        }
    }

    private var wizardForm: some View {
        Form {
            Section {
                ArcCompactHeroHeader(
                    systemImage: step.systemImage,
                    title: step.title,
                    summary: stepProgressSummary
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            currentStepContent

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
        .onChange(of: shootWindowMode) { _, _ in clearFetchedContext() }
        .onChange(of: shootDate) { _, _ in clearFetchedContext() }
        .onChange(of: shootStartTime) { _, _ in clearFetchedContext() }
        .onChange(of: shootEndTime) { _, _ in clearFetchedContext() }
    }

    private var locationStepScreen: some View {
        ShootSpotPickerView(
            viewModel: locationViewModel,
            systemImage: step.systemImage,
            title: step.title,
            subtitle: step.subtitle,
            badges: [ArcHeroBadge(label: "\(step.rawValue + 1) of \(NewShootStep.allCases.count)", systemImage: "list.number")],
            primaryButtonTitle: "Continue",
            primarySystemImage: "arrow.right",
            primaryAction: continueFromLocation
        )
    }

    private var stepProgressSummary: String {
        "\(step.rawValue + 1) of \(NewShootStep.allCases.count)"
    }

    @ViewBuilder
    private var currentStepContent: some View {
        switch step {
        case .location:
            EmptyView()
        case .framing:
            framingStep
        case .notes:
            notesStep
        case .generate:
            generateStep
        case .review:
            reviewStep
        }
    }

    private var framingStep: some View {
        Section {
            ArcFeatureCard(accent: ArcPalette.tint) {
                ArcFeatureTitle(
                    systemImage: "slider.horizontal.3",
                    title: "Framing",
                    subtitle: "Choose the output and shoot window before generating the checklist."
                )

                ShootPlanningControls(
                    outputIntent: $outputIntent,
                    shootWindowMode: $shootWindowMode,
                    shootDate: $shootDate,
                    shootStartTime: $shootStartTime,
                    shootEndTime: $shootEndTime
                )

                framingContextControl

                wizardButtons(
                    backTitle: "Back",
                    primaryTitle: "Next",
                    primaryAction: { step = .notes },
                    backAction: { step = .location }
                )
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var framingContextControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: hasFetchedContext ? "checkmark.circle.fill" : "map.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(hasFetchedContext ? ArcPalette.tint : ArcPalette.glowPrimary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(hasFetchedContext ? "Context ready" : "Location context")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(contextSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task {
                    await fetchContextForDraft()
                }
            } label: {
                HStack(spacing: 8) {
                    if isFetchingContext {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text(isFetchingContext ? "Fetching..." : (hasFetchedContext ? "Refresh Context" : "Fetch Context"))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.glass)
            .disabled(isFetchingContext || isGenerating || isCommitting)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }

    private var hasFetchedContext: Bool {
        !generatedEnrichmentJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var contextSummary: String {
        if let generatedLastEnrichedAt, hasFetchedContext {
            return "Cached \(generatedLastEnrichedAt.formatted(date: .abbreviated, time: .shortened)). Generation will use landmarks, weather, references, and sun/moon timing."
        }

        return "Fetch landmarks, weather, references, and sun/moon timing before generating."
    }

    private var notesStep: some View {
        Section {
            ArcFeatureCard(accent: ArcPalette.glowSecondary) {
                ArcFeatureTitle(
                    systemImage: "note.text",
                    title: "Notes",
                    subtitle: "Optional creative direction, constraints, or shots you already know you need."
                )

                ShootNotesEditor(notes: $notes)

                wizardButtons(
                    backTitle: "Back",
                    primaryTitle: "Generate Plan",
                    primaryAction: {
                        Task { await generateDraft() }
                    },
                    backAction: { step = .framing }
                )
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var generateStep: some View {
        Section {
            ArcFeatureCard(accent: ArcPalette.tint) {
                ArcFeatureTitle(
                    systemImage: "sparkles.rectangle.stack",
                    title: isGenerating ? "Generating" : "Generation Paused",
                    subtitle: isGenerating ? "Fetching context and building a field-ready checklist." : "Try again when you are ready."
                )

                if isGenerating {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !isGenerating {
                    wizardButtons(
                        backTitle: "Back",
                        primaryTitle: "Retry",
                        primaryAction: {
                            Task { await generateDraft() }
                        },
                        backAction: { step = .notes }
                    )
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var reviewStep: some View {
        Section {
            ArcFeatureCard(accent: ArcPalette.tint) {
                ArcFeatureTitle(
                    systemImage: "checklist",
                    title: "Review Draft",
                    subtitle: draftItems.isEmpty ? "Regenerate if the response did not produce checklist items." : "\(draftItems.count) checklist items ready."
                )

                if draftItems.isEmpty {
                    Text(rawResponse.isEmpty ? "No generated response is available." : rawResponse)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    ShootDraftList(
                        items: draftItems,
                        onEdit: beginEditing,
                        onDelete: deleteDraft
                    )
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        Button("Regenerate") {
                            step = .framing
                        }
                        .buttonStyle(.glass)

                        Button {
                            Task { await commitShoot() }
                        } label: {
                            HStack(spacing: 8) {
                                if isCommitting {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(isCommitting ? "Saving..." : "Use this plan")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(isCommitting || draftItems.isEmpty)
                    }

                    VStack(spacing: 10) {
                        Button("Regenerate") {
                            step = .framing
                        }
                        .buttonStyle(.glass)

                        Button {
                            Task { await commitShoot() }
                        } label: {
                            HStack(spacing: 8) {
                                if isCommitting {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(isCommitting ? "Saving..." : "Use this plan")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(isCommitting || draftItems.isEmpty)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var draftEditSheet: some View {
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
                        editingDraft = nil
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveDraftEdits()
                    }
                }
            }
        }
    }

    private func wizardButtons(
        backTitle: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        backAction: @escaping () -> Void
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Button(backTitle, action: backAction)
                    .buttonStyle(.glass)
                    .disabled(isFetchingContext || isGenerating || isCommitting)

                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.glassProminent)
                    .disabled(isFetchingContext || isGenerating || isCommitting)
            }

            VStack(spacing: 10) {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.glassProminent)
                    .disabled(isFetchingContext || isGenerating || isCommitting)

                Button(backTitle, action: backAction)
                    .buttonStyle(.glass)
                    .disabled(isFetchingContext || isGenerating || isCommitting)
            }
        }
    }

    private func continueFromLocation() {
        guard let draft = locationViewModel.validatedDraft() else {
            return
        }

        locationDraft = draft
        clearFetchedContext()
        errorMessage = nil
        step = .framing
    }

    private func clearFetchedContext() {
        generatedEnrichmentJSON = ""
        generatedLastEnrichedAt = nil
    }

    private func fetchContextForDraft() async {
        guard !isFetchingContext else {
            return
        }

        guard let locationDraft = locationDraft ?? locationViewModel.validatedDraft(),
              let input = generationInput()
        else {
            return
        }

        self.locationDraft = locationDraft
        isFetchingContext = true
        errorMessage = nil
        defer { isFetchingContext = false }

        let transientLocation = ShootLocation(
            name: locationDraft.name,
            latitude: locationDraft.coordinate.latitude,
            longitude: locationDraft.coordinate.longitude
        )
        let contextBundle = await locationEnricher.enrich(
            location: transientLocation,
            shootWindow: DateInterval(start: input.shootWindowStart, end: input.shootWindowEnd)
        )

        do {
            generatedEnrichmentJSON = try contextBundle.formattedJSONString()
            generatedLastEnrichedAt = contextBundle.generatedAt
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func generateDraft() async {
        guard let locationDraft = locationDraft ?? locationViewModel.validatedDraft(),
              let input = generationInput()
        else {
            return
        }

        self.locationDraft = locationDraft
        step = .generate
        isGenerating = true
        errorMessage = nil

        defer { isGenerating = false }

        let transientLocation = ShootLocation(
            name: locationDraft.name,
            latitude: locationDraft.coordinate.latitude,
            longitude: locationDraft.coordinate.longitude
        )

        do {
            if hasFetchedContext {
                transientLocation.enrichmentJSON = generatedEnrichmentJSON
                transientLocation.lastEnrichedAt = generatedLastEnrichedAt
            } else {
                let contextBundle = await locationEnricher.enrich(
                    location: transientLocation,
                    shootWindow: DateInterval(start: input.shootWindowStart, end: input.shootWindowEnd)
                )
                if let formattedContext = try? contextBundle.formattedJSONString() {
                    transientLocation.enrichmentJSON = formattedContext
                    transientLocation.lastEnrichedAt = contextBundle.generatedAt
                    generatedEnrichmentJSON = formattedContext
                    generatedLastEnrichedAt = contextBundle.generatedAt
                }
            }

            let result = try await generator.generate(for: transientLocation, input: input)
            rawResponse = result.rawResponse
            draftItems = result.drafts.map(ShootDraftItem.init)
            step = .review
        } catch {
            errorMessage = error.localizedDescription
            step = .generate
        }
    }

    private func commitShoot() async {
        guard let locationDraft, !draftItems.isEmpty else {
            errorMessage = "Generate a draft before starting field mode."
            return
        }

        guard generationInput() != nil else {
            return
        }

        isCommitting = true
        errorMessage = nil
        defer { isCommitting = false }

        let location = ShootLocation(
            name: locationDraft.name,
            latitude: locationDraft.coordinate.latitude,
            longitude: locationDraft.coordinate.longitude,
            enrichmentJSON: generatedEnrichmentJSON,
            lastEnrichedAt: generatedLastEnrichedAt
        )
        let plan = ShootPlan(
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            rawResponse: rawResponse,
            outputIntent: outputIntent,
            shootWindowMode: shootWindowMode,
            shootWindowSummary: shootWindowSummary,
            shootDate: shootDate,
            shootStartTime: shootStartTime,
            shootEndTime: shootEndTime,
            isApprovedForField: true,
            approvedAt: Date(),
            completedAt: nil,
            location: location
        )

        location.plan = plan
        modelContext.insert(location)
        modelContext.insert(plan)

        for (index, draft) in draftItems.enumerated() {
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

        do {
            try modelContext.save()
            _ = await referenceImageCache.cacheReferenceImages(for: location)
            onCommit(location)
            dismiss()
        } catch {
            modelContext.delete(location)
            errorMessage = error.localizedDescription
        }
    }

    private func generationInput() -> ShotListGenerationInput? {
        switch shootWindowMode {
        case .now:
            return ShotListGenerationInput(
                outputIntent: outputIntent,
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
                notes: notes,
                shootWindowMode: .custom,
                shootWindowStart: window.start,
                shootWindowEnd: window.end
            )
        }
    }

    private var shootWindowSummary: String {
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

    private func beginEditing(_ draft: ShootDraftItem) {
        editTitle = draft.title
        editRole = draft.role
        editGuidance = draft.guidance
        editingDraft = draft
    }

    private func saveDraftEdits() {
        guard let editingDraft,
              let index = draftItems.firstIndex(where: { $0.id == editingDraft.id })
        else {
            return
        }

        let cleanTitle = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRole = editRole.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGuidance = editGuidance.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty, !cleanGuidance.isEmpty else {
            return
        }

        draftItems[index].title = cleanTitle
        draftItems[index].role = cleanRole.isEmpty ? "Support" : cleanRole
        draftItems[index].guidance = cleanGuidance
        rawResponse = ShotPlanParser.formattedResponse(
            from: draftItems.map(\.plannedShotDraft),
            fallback: rawResponse
        )
        self.editingDraft = nil
    }

    private func deleteDraft(_ draft: ShootDraftItem) {
        draftItems.removeAll { $0.id == draft.id }
        rawResponse = ShotPlanParser.formattedResponse(
            from: draftItems.map(\.plannedShotDraft),
            fallback: rawResponse
        )
    }
}

private enum NewShootStep: Int, CaseIterable {
    case location
    case framing
    case notes
    case generate
    case review

    var title: String {
        switch self {
        case .location:
            return "Choose Location"
        case .framing:
            return "Shape the Shoot"
        case .notes:
            return "Add Notes"
        case .generate:
            return "Generate Plan"
        case .review:
            return "Use the Plan"
        }
    }

    var subtitle: String {
        switch self {
        case .location:
            return "Start with the place you are about to shoot."
        case .framing:
            return "Pick output, timing, and the checklist shape."
        case .notes:
            return "Add the creative details the model cannot infer."
        case .generate:
            return "Arc is turning the setup into a field checklist."
        case .review:
            return "Tighten the checklist before field mode starts."
        }
    }

    var systemImage: String {
        switch self {
        case .location:
            return "location.viewfinder"
        case .framing:
            return "slider.horizontal.3"
        case .notes:
            return "note.text"
        case .generate:
            return "sparkles.rectangle.stack"
        case .review:
            return "checklist"
        }
    }
}

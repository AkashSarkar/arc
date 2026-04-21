import SwiftData
import SwiftUI

struct PlanView: View {
    let location: ShootLocation
    let locationEnricher: any LocationEnriching
    let referenceImageCache: any ReferenceImageCaching

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: PlanViewModel
    @State private var navigationTarget: PlanNavigationTarget?
    @State private var isRefreshingContext = false
    @State private var contextRefreshError: String?
    @State private var editingItem: ShootPlanItem?
    @State private var editTitle: String = ""
    @State private var editRole: String = ""
    @State private var editGuidance: String = ""

    init(
        location: ShootLocation,
        aiService: any AIServicing,
        locationEnricher: any LocationEnriching,
        referenceImageCache: any ReferenceImageCaching
    ) {
        self.location = location
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

    var body: some View {
        Form {
            Section {
                ArcHeroHeader(
                    systemImage: "sparkles.rectangle.stack",
                    title: "Plan Shoot",
                    subtitle: "Pick output and timing, then generate a draft for this location. Cached context is included when available."
                ) {
                    PlanLocationContextRow(locationName: location.name)

                    PlanPromptContextRow(
                        hasCachedContext: hasCachedContext,
                        lastEnrichedAt: location.lastEnrichedAt,
                        isRefreshing: isRefreshingContext,
                        onRefresh: {
                            Task { await refreshContext() }
                        },
                        onInspect: {
                            navigationTarget = .context
                        }
                    )

                    if let contextRefreshError {
                        Text(contextRefreshError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    HStack(spacing: 10) {
                        PlanFilterMenu(
                            systemImage: "square.stack.3d.up",
                            title: "Output",
                            selection: $viewModel.outputIntent,
                            options: OutputIntent.allCases,
                            optionTitle: \.title
                        )

                        PlanFilterMenu(
                            systemImage: "calendar.badge.clock",
                            title: "Timing",
                            selection: $viewModel.shootWindowMode,
                            options: ShootWindowMode.allCases,
                            optionTitle: \.title
                        )
                    }

                    if viewModel.shootWindowMode == .custom {
                        PlanCustomWindowEditor(
                            shootDate: $viewModel.shootDate,
                            shootStartTime: $viewModel.shootStartTime,
                            shootEndTime: $viewModel.shootEndTime
                        )
                    }

                    Text(planSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if viewModel.cachedReferenceTotal > 0 {
                        Label(
                            "Offline references: \(viewModel.cachedReferenceCount)/\(viewModel.cachedReferenceTotal)",
                            systemImage: "arrow.down.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ArcFeatureCard {
                    ArcFeatureTitle(
                        systemImage: "note.text",
                        title: "Notes",
                        subtitle: nil
                    )

                    TextEditor(text: $viewModel.notes)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 140)
                        .padding(12)
                        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
                        }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ArcFeatureCard(accent: ArcPalette.tint) {
                    Button {
                        Task {
                            await viewModel.generatePlan(for: location, modelContext: modelContext)
                        }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            Text(viewModel.isLoading ? "Generating..." : "Generate Plan")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(viewModel.isLoading)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

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

            if !viewModel.response.isEmpty {
                Section {
                    ArcFeatureCard(accent: ArcPalette.glowSecondary) {
                        ArcFeatureTitle(
                            systemImage: "text.alignleft",
                            title: "Draft Plan",
                            subtitle: viewModel.isDraftApproved ? "Saved for field and review." : "Review and save for field."
                        )

                        Text(savedPlanSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("To edit this plan, change the notes, output, or timing above and generate again.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if !draftItems.isEmpty {
                            PlanDraftCardStack(
                                items: draftItems,
                                onEdit: beginEditing,
                                onDelete: deleteDraftItem
                            )
                        } else {
                            Text(viewModel.response)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) {
                                planSaveButton
                                planOpenFieldButton
                                planOpenReviewButton
                            }

                            VStack(spacing: 10) {
                                planSaveButton
                                planOpenFieldButton
                                planOpenReviewButton
                            }
                        }
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
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.shootStartTime) { _, _ in
            viewModel.ensureDefaultWindowTimes()
        }
        .task(id: location.enrichmentJSON) {
            viewModel.refreshReferenceCacheStatus(for: location)
        }
        .navigationDestination(item: $navigationTarget) { target in
            switch target {
            case .field:
                FieldView(location: location)
            case .review:
                ReviewView(location: location)
            case .context:
                LocationContextView(location: location, locationEnricher: locationEnricher)
            }
        }
        .sheet(item: $editingItem) { _ in
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
                            saveDraftEdits()
                        }
                    }
                }
            }
        }
    }

    private var planSummary: String {
        if viewModel.shootWindowMode == .custom {
            return "\(viewModel.outputIntent.defaultShotCount) shots. \(viewModel.shootWindowSummary)"
        }

        return "\(viewModel.outputIntent.defaultShotCount) shots. Use current conditions."
    }

    private var savedPlanSummary: String {
        if let approvedAt = location.plan?.approvedAt, viewModel.isDraftApproved {
            return "Saved for field on \(approvedAt.formatted(date: .abbreviated, time: .shortened))."
        }

        guard location.plan?.createdAt != nil else {
            return "Generate a draft first."
        }

        return "Draft generated. Save to make it available in field mode."
    }

    @ViewBuilder
    private var planSaveButton: some View {
        Button {
            viewModel.approveDraft(for: location, modelContext: modelContext)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isDraftApproved ? "checkmark.seal.fill" : "square.and.arrow.down")
                Text(viewModel.isDraftApproved ? "Saved for Field" : "Save Plan")
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .disabled(viewModel.isDraftApproved || viewModel.isLoading || draftItems.isEmpty)
    }

    @ViewBuilder
    private var planOpenFieldButton: some View {
        Button {
            navigationTarget = .field
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                Text("Open Field")
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
    }

    @ViewBuilder
    private var planOpenReviewButton: some View {
        Button {
            navigationTarget = .review
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle")
                Text("Open Review")
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
    }

    private var hasCachedContext: Bool {
        !location.enrichmentJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var draftItems: [ShootPlanItem] {
        location.plan?.orderedItems ?? []
    }

    private func refreshContext() async {
        isRefreshingContext = true
        contextRefreshError = nil
        defer { isRefreshingContext = false }

        let bundle = await locationEnricher.enrich(location: location, shootWindow: nil)

        do {
            let formattedJSON = try bundle.formattedJSONString()
            location.enrichmentJSON = formattedJSON
            location.lastEnrichedAt = bundle.generatedAt
            try modelContext.save()
            viewModel.refreshReferenceCacheStatus(for: location)
        } catch {
            contextRefreshError = error.localizedDescription
        }
    }

    private func beginEditing(_ item: ShootPlanItem) {
        editTitle = item.title
        editRole = item.role
        editGuidance = item.guidance
        editingItem = item
    }

    private func saveDraftEdits() {
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
        markDraftNeedsResave()
        editingItem = nil
    }

    private func deleteDraftItem(_ item: ShootPlanItem) {
        guard let plan = location.plan else {
            return
        }

        let remainingItems = plan.orderedItems.filter { $0.id != item.id }
        for (index, remainingItem) in remainingItems.enumerated() {
            remainingItem.orderIndex = index
        }

        plan.items.removeAll { $0.id == item.id }
        modelContext.delete(item)
        markDraftNeedsResave()
    }

    private func markDraftNeedsResave() {
        guard let plan = location.plan else {
            return
        }

        plan.isApprovedForField = false
        plan.approvedAt = nil
        viewModel.isDraftApproved = false
        try? modelContext.save()
    }
}

private struct PlanDraftCardStack: View {
    let items: [ShootPlanItem]
    let onEdit: (ShootPlanItem) -> Void
    let onDelete: (ShootPlanItem) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                PlanDraftItemRow(
                    sequenceNumber: index + 1,
                    item: item,
                    onEdit: { onEdit(item) },
                    onDelete: { onDelete(item) }
                )
            }
        }
    }
}

private struct PlanDraftItemRow: View {
    let sequenceNumber: Int
    let item: ShootPlanItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Shot \(sequenceNumber)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ArcPalette.glowPrimary.opacity(0.15), in: Capsule())
                    .foregroundStyle(ArcPalette.glowPrimary)

                Text(item.title)
                    .font(.headline)
                Spacer(minLength: 0)
                Text(item.role)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ArcPalette.tint.opacity(0.14), in: Capsule())
                    .foregroundStyle(ArcPalette.tint)
            }

            Text(item.guidance)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("Edit", action: onEdit)
                    .buttonStyle(.glass)
                Button("Delete", role: .destructive, action: onDelete)
                    .buttonStyle(.glass)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private enum PlanNavigationTarget: String, Identifiable {
    case field
    case review
    case context

    var id: String { rawValue }
}

private struct PlanLocationContextRow: View {
    let locationName: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ArcPalette.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("Planning for")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(locationName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct PlanPromptContextRow: View {
    let hasCachedContext: Bool
    let lastEnrichedAt: Date?
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onInspect: () -> Void

    private var title: String {
        hasCachedContext ? "Context ready" : "No context yet"
    }

    private var subtitle: String {
        if let lastEnrichedAt, hasCachedContext {
            return "Cached \(lastEnrichedAt.formatted(date: .abbreviated, time: .shortened)). Landmarks, weather, and timing will ground the prompt."
        }

        return "Fetch context to include landmarks, weather, and sun/moon timing in the prompt."
    }

    private var systemImage: String {
        hasCachedContext ? "checkmark.circle.fill" : "exclamationmark.circle"
    }

    private var tint: Color {
        hasCachedContext ? ArcPalette.tint : ArcPalette.glowPrimary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Button(action: onRefresh) {
                    HStack(spacing: 6) {
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(isRefreshing ? "Refreshing..." : (hasCachedContext ? "Refresh" : "Fetch Context"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .disabled(isRefreshing)

                if hasCachedContext {
                    Button(action: onInspect) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Inspect")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct PlanCustomWindowEditor: View {
    @Binding var shootDate: Date
    @Binding var shootStartTime: Date
    @Binding var shootEndTime: Date

    var body: some View {
        VStack(spacing: 10) {
            PlanCompactDatePickerRow(
                title: "Date",
                selection: $shootDate,
                displayedComponents: .date
            )

            PlanCompactDatePickerRow(
                title: "Start",
                selection: $shootStartTime,
                displayedComponents: .hourAndMinute
            )

            PlanCompactDatePickerRow(
                title: "End",
                selection: $shootEndTime,
                displayedComponents: .hourAndMinute
            )
        }
        .padding(14)
        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct PlanCompactDatePickerRow: View {
    let title: String
    @Binding var selection: Date
    let displayedComponents: DatePickerComponents

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            DatePicker(title, selection: $selection, displayedComponents: displayedComponents)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
    }
}

private struct PlanFilterMenu<Option: Identifiable & Hashable>: View {
    let systemImage: String
    let title: String
    @Binding var selection: Option
    let options: [Option]
    let optionTitle: KeyPath<Option, String>

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    HStack {
                        Text(option[keyPath: optionTitle])

                        if option == selection {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ArcPalette.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(selection[keyPath: optionTitle])
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

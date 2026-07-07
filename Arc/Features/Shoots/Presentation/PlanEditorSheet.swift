import SwiftData
import SwiftUI

struct PlanEditorSheet: View {
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSection: PlanEditorSection = .checklist
    @State private var editingItem: CaptureItem?
    @State private var title: String
    @State private var summary: String

    init(
        trip: Trip,
        aiService: any AIServicing,
        locationEnricher: any LocationEnriching,
        referenceImageCache: any ReferenceImageCaching
    ) {
        self.trip = trip
        _title = State(initialValue: trip.title)
        _summary = State(initialValue: trip.summary)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ArcCompactHeroHeader(
                        systemImage: "slider.horizontal.3",
                        title: "Edit Capture Plan",
                        summary: trip.title
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    Picker("Plan section", selection: $selectedSection) {
                        ForEach(PlanEditorSection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                currentPlanSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(ArcSceneBackground())
            .navigationTitle("Capture Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveMetadata()
                        dismiss()
                    }
                }
            }
            .sheet(item: $editingItem) { item in
                CaptureItemEditSheet(item: item) {
                    try? modelContext.save()
                }
            }
        }
    }

    @ViewBuilder
    private var currentPlanSection: some View {
        switch selectedSection {
        case .checklist:
            checklistSection
        case .trip:
            tripSection
        case .exports:
            exportSection
        }
    }

    private var tripSection: some View {
        Section {
            ArcFeatureCard(accent: ArcPalette.tint) {
                ArcFeatureTitle(
                    systemImage: "text.cursor",
                    title: "Trip Details",
                    subtitle: "These values are included in exports.",
                    accent: ArcPalette.tint
                )

                TextField("Trip title", text: $title)
                    .textFieldStyle(.roundedBorder)

                TextField("Summary", text: $summary, axis: .vertical)
                    .lineLimit(3...7)
                    .textFieldStyle(.roundedBorder)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var checklistSection: some View {
        Section {
            ArcFeatureCard(accent: ArcPalette.glowPrimary) {
                ArcFeatureTitle(
                    systemImage: "checklist",
                    title: "Field Guide",
                    subtitle: trip.allItems.isEmpty ? "No items are saved yet." : "\(trip.allItems.count) live items",
                    accent: ArcPalette.glowPrimary
                )

                if trip.orderedStops.isEmpty {
                    Text("Add or import stops to create a field guide.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(trip.orderedStops) { stop in
                        stopEditor(stop)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var exportSection: some View {
        Section {
            ArcFeatureCard(accent: ArcPalette.glowSecondary) {
                ArcFeatureTitle(
                    systemImage: "square.and.arrow.up",
                    title: "Export Preview",
                    subtitle: "\(trip.resolvedCount)/\(trip.allItems.count) resolved",
                    accent: ArcPalette.glowSecondary
                )

                Text(TripDocumentMapper.markdownExport(for: trip))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func stopEditor(_ stop: Stop) -> some View {
        ArcInlinePanel {
            ArcFeatureTitle(
                systemImage: "mappin.and.ellipse",
                title: stop.name,
                subtitle: "\(stop.orderedStages.count) stages",
                accent: ArcPalette.tint
            )

            ForEach(stop.orderedStages) { stage in
                stageEditor(stage)
            }
        }
    }

    private func stageEditor(_ stage: Stage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(stage.title)
                    .font(.headline)

                Spacer()

                Button {
                    addItem(to: stage)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add item")
            }

            if !stage.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(stage.goal)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if stage.orderedItems.isEmpty {
                Text("No items in this stage.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                CaptureItemList(
                    items: stage.orderedItems,
                    onEdit: { editingItem = $0 },
                    onDelete: deleteItem
                )
            }
        }
        .padding(12)
        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }

    private func saveMetadata() {
        trip.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? trip.title : title
        trip.summary = summary
        try? modelContext.save()
    }

    private func addItem(to stage: Stage) {
        let item = CaptureItem(
            orderIndex: stage.orderedItems.count,
            title: "New field item",
            guidance: "Add the field guidance before capture.",
            kind: .shot,
            priority: .optional,
            origin: .fieldAdded,
            stage: stage
        )
        stage.items.append(item)
        try? modelContext.save()
        editingItem = item
    }

    private func deleteItem(_ item: CaptureItem) {
        if let stage = item.stage {
            stage.items.removeAll { $0.id == item.id }
            for (index, item) in stage.orderedItems.enumerated() {
                item.orderIndex = index
            }
        }

        modelContext.delete(item)
        try? modelContext.save()
    }
}

private struct CaptureItemEditSheet: View {
    let item: CaptureItem
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var guidance: String
    @State private var kind: FieldGuideItemKind
    @State private var priority: FieldGuidePriority
    @State private var isBeforeLeaving: Bool

    init(item: CaptureItem, onSave: @escaping () -> Void) {
        self.item = item
        self.onSave = onSave
        _title = State(initialValue: item.title)
        _guidance = State(initialValue: item.guidance)
        _kind = State(initialValue: item.kind)
        _priority = State(initialValue: item.priority)
        _isBeforeLeaving = State(initialValue: item.isBeforeLeaving)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Title", text: $title)
                    TextField("Guidance", text: $guidance, axis: .vertical)
                        .lineLimit(3...7)
                }

                Section("Role") {
                    Picker("Kind", selection: $kind) {
                        ForEach(FieldGuideItemKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }

                    Picker("Priority", selection: $priority) {
                        ForEach(FieldGuidePriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }

                    Toggle("Before leaving", isOn: $isBeforeLeaving)
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() {
        item.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? item.title : title
        item.guidance = guidance
        item.kind = kind
        item.priority = priority
        item.isBeforeLeaving = isBeforeLeaving
        onSave()
    }
}

private enum PlanEditorSection: String, CaseIterable, Identifiable {
    case checklist
    case trip
    case exports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .checklist:
            return "Guide"
        case .trip:
            return "Trip"
        case .exports:
            return "Export"
        }
    }
}

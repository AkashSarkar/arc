import SwiftData
import SwiftUI
import UIKit

struct ImportPlanFlowView: View {
    let aiService: any AIServicing
    let onCommit: (ShootLocation) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var projectTitle = ""
    @State private var planText = ""
    @State private var draft = FieldGuideDraft.empty
    @State private var isImprovingWithAI = false
    @State private var isCommitting = false
    @State private var errorMessage: String?

    private var canCreatePlan: Bool {
        !projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !planText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.itemCount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                setupSection
                draftSection

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
            .navigationTitle("Import Plan")
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
                        Task { await improveWithAI() }
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
    }

    private var setupSection: some View {
        Section {
            ArcFeatureCard(accent: ArcPalette.tint) {
                ArcFeatureTitle(
                    systemImage: "square.and.arrow.down",
                    title: "Import Existing Plan",
                    subtitle: "Paste your Apple Notes plan. Arc creates editable field stages without requiring AI."
                )

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
                    }

                    VStack(spacing: 10) {
                        pasteButton
                        rebuildButton
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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
                        Label("Improving with AI...", systemImage: "sparkles")
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
        Button {
            if let clipboardText = UIPasteboard.general.string,
               !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                planText = clipboardText
                errorMessage = nil
            } else {
                errorMessage = "Clipboard does not contain text."
            }
        } label: {
            Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
    }

    private var rebuildButton: some View {
        Button {
            rebuildLocalDraft()
        } label: {
            Label("Rebuild Local Draft", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .disabled(projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || planText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var canImproveWithAI: Bool {
        !projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !planText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func rebuildLocalDraft() {
        let title = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = planText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !text.isEmpty else {
            draft = .empty
            return
        }

        draft = ImportedPlanParser.parse(title: title, text: text)
        errorMessage = nil
    }

    private func improveWithAI() async {
        let title = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = planText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !text.isEmpty else {
            return
        }

        isImprovingWithAI = true
        errorMessage = nil
        defer { isImprovingWithAI = false }

        do {
            draft = try await ImportedPlanGenerator(aiService: aiService).improve(title: title, text: text)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addStage() {
        draft.stages.append(
            FieldGuideStageDraft(
                title: "New Stage",
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
        let title = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = planText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canCreatePlan else {
            errorMessage = "Add a title, paste a plan, and keep at least one field item."
            return
        }

        isCommitting = true
        errorMessage = nil
        defer { isCommitting = false }

        let location = ShootLocation(name: title, latitude: 0, longitude: 0)
        let plan = ShootPlan(
            notes: text,
            rawResponse: text,
            source: .importedText,
            importedPlanText: text,
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

            for item in stage.items where !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let planItem = ShootPlanItem(
                    orderIndex: globalOrderIndex,
                    title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    role: item.kind.title,
                    guidance: item.guidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Capture this clearly enough to use in the edit." : item.guidance,
                    stageTitle: stageTitle,
                    stageOrderIndex: stageIndex,
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
        }
        .padding(12)
        .background(ArcPalette.solidFieldSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

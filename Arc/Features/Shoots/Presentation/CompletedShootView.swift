import SwiftData
import SwiftUI
import UIKit

struct CompletedShootView: View {
    let location: ShootLocation

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isConfirmingDelete = false
    @State private var selectedSection: CompletedShootSection = .captured

    private var plan: ShootPlan? {
        location.plan
    }

    private var planItems: [ShootPlanItem] {
        plan?.orderedItems ?? []
    }

    private var capturedItems: [ShootPlanItem] {
        planItems.filter(\.isCaptured)
    }

    private var skippedItems: [ShootPlanItem] {
        planItems.filter(\.isSkipped)
    }

    private var missingItems: [ShootPlanItem] {
        planItems.filter { !$0.isResolved }
    }

    private var fieldStages: [FieldGuideStage] {
        plan?.fieldStages ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ArcCompactHeroHeader(
                    systemImage: "checkmark.seal.fill",
                    title: location.name,
                    summary: completedSummary,
                    tint: ArcPalette.tint
                )

                ArcDenseCard(accent: ArcPalette.glowSecondary) {
                    ArcFeatureTitle(
                        systemImage: "chart.bar.xaxis",
                        title: "Coverage Snapshot",
                        subtitle: nil,
                        accent: ArcPalette.glowSecondary
                    )

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            ArcMetricTile(title: "Planned", value: "\(planItems.count)", systemImage: "checklist", accent: ArcPalette.glowSecondary)
                            ArcMetricTile(title: "Captured", value: "\(plan?.capturedCount ?? 0)", systemImage: "checkmark.circle", accent: ArcPalette.tint)
                            ArcMetricTile(title: "Skipped", value: "\(plan?.skippedCount ?? 0)", systemImage: "forward.circle", accent: ArcPalette.glowSecondary)
                            ArcMetricTile(title: "Missing", value: "\(plan?.missingCount ?? 0)", systemImage: "circle.dashed", accent: ArcPalette.glowPrimary)
                        }

                        VStack(spacing: 10) {
                            ArcMetricTile(title: "Planned", value: "\(planItems.count)", systemImage: "checklist", accent: ArcPalette.glowSecondary)
                            ArcMetricTile(title: "Captured", value: "\(plan?.capturedCount ?? 0)", systemImage: "checkmark.circle", accent: ArcPalette.tint)
                            ArcMetricTile(title: "Skipped", value: "\(plan?.skippedCount ?? 0)", systemImage: "forward.circle", accent: ArcPalette.glowSecondary)
                            ArcMetricTile(title: "Missing", value: "\(plan?.missingCount ?? 0)", systemImage: "circle.dashed", accent: ArcPalette.glowPrimary)
                        }
                    }
                }

                if let plan, plan.source == .importedText {
                    StoryCompletenessCard(plan: plan, items: planItems)
                }

                Picker("Completed section", selection: $selectedSection) {
                    ForEach(CompletedShootSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)

                ArcFeatureCard(accent: selectedSection.accent) {
                    ArcFeatureTitle(
                        systemImage: selectedSection.systemImage,
                        title: selectedSection.title,
                        subtitle: selectedItems.isEmpty ? selectedSection.emptyTitle : "\(selectedItems.count) items",
                        accent: selectedSection.accent
                    )

                    if selectedItems.isEmpty {
                        Text(selectedSection.emptyMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(selectedItems) { item in
                            CompletedShotRow(
                                systemImage: selectedSection.systemImage,
                                item: item,
                                tint: selectedSection.accent
                            )
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(ArcSceneBackground())
        .navigationTitle("Completed")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: completedExportText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share summary")

                Button {
                    reopen()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel("Reopen plan")

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete plan")
            }
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
    }

    private var selectedItems: [ShootPlanItem] {
        switch selectedSection {
        case .captured:
            return capturedItems
        case .skipped:
            return skippedItems
        case .missing:
            return missingItems
        }
    }

    private var completedSummary: String {
        guard let plan else {
            return "Completed"
        }

        if let completedAt = plan.completedAt {
            return "\(plan.resolvedCount)/\(planItems.count) resolved • \(completedAt.formatted(date: .abbreviated, time: .shortened))"
        }

        return "\(plan.resolvedCount)/\(planItems.count) resolved"
    }

    private var completedExportText: String {
        guard let plan else {
            return "\(location.name)\nCompleted Capture Plan"
        }

        var sections: [String] = []
        sections.append("Arc Capture Plan")
        sections.append(location.name)
        sections.append("Content: \(plan.outputIntent.title)")
        sections.append("Capture: \(plan.captureMedium.title)")
        sections.append("Platform: \(plan.targetPlatform.title)")
        sections.append("Style: \(plan.stylePreset.title)")
        sections.append("Timing: \(plan.shootWindowSummary)")

        if let completedAt = plan.completedAt {
            sections.append("Completed: \(completedAt.formatted(date: .abbreviated, time: .shortened))")
        }

        sections.append("Coverage: \(plan.capturedCount) captured, \(plan.skippedCount) skipped, \(plan.missingCount) missing")

        if !fieldStages.isEmpty {
            sections.append(
                (["Editing Outline"] + fieldStages.map(stageExportBlock))
                    .joined(separator: "\n\n")
            )
        } else if !planItems.isEmpty {
            sections.append(
                (["Items"] + planItems.map(itemExportLine))
                    .joined(separator: "\n")
            )
        }

        let noteLines = planItems
            .filter { !$0.fieldNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "- \($0.title): \($0.fieldNote)" }
        if !noteLines.isEmpty {
            sections.append((["Field Notes"] + noteLines).joined(separator: "\n"))
        }

        return sections.joined(separator: "\n\n")
    }

    private func stageExportBlock(_ stage: FieldGuideStage) -> String {
        var lines = ["\(stage.title)"]

        let captured = stage.items.filter(\.isCaptured)
        if !captured.isEmpty {
            lines.append("Captured")
            lines.append(contentsOf: captured.map(itemExportLine))
        }

        let skipped = stage.items.filter(\.isSkipped)
        if !skipped.isEmpty {
            lines.append("Skipped")
            lines.append(contentsOf: skipped.map(itemExportLine))
        }

        let missing = stage.items.filter { !$0.isResolved }
        if !missing.isEmpty {
            lines.append("Missing")
            lines.append(contentsOf: missing.map(itemExportLine))
        }

        return lines.joined(separator: "\n")
    }

    private func itemExportLine(_ item: ShootPlanItem) -> String {
        var line = "- \(item.title) (\(item.displayRoleTitle), \(item.priority.title)): \(item.guidance)"
        let note = item.fieldNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            line += " Note: \(note)"
        }
        return line
    }

    private func reopen() {
        location.plan?.completedAt = nil
        try? modelContext.save()
        dismiss()
    }

    private func deleteShoot() {
        modelContext.delete(location)
        try? modelContext.save()
        dismiss()
    }
}

private struct CompletedShotRow: View {
    let systemImage: String
    let item: ShootPlanItem
    let tint: Color

    private var thumbnailImage: UIImage? {
        guard let data = item.capturedPhotoData else {
            return nil
        }

        return UIImage(data: data)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                ArcMiniIconBadge(systemImage: systemImage, tint: tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)

                    Text("\(item.displayRoleTitle) - \(item.priority.title). \(item.guidance)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                    .frame(height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}

private struct StoryCompletenessCard: View {
    let plan: ShootPlan
    let items: [ShootPlanItem]

    private var capturedItems: [ShootPlanItem] {
        items.filter(\.isCaptured)
    }

    var body: some View {
        ArcDenseCard(accent: ArcPalette.tint) {
            ArcFeatureTitle(
                systemImage: "film.stack",
                title: "Story Completeness",
                subtitle: plan.storySummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : plan.storySummary,
                accent: ArcPalette.tint
            )

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    metric("Beginning", hasBeginning, "1.circle")
                    metric("Middle", hasMiddle, "2.circle")
                    metric("Ending", hasEnding, "3.circle")
                }

                VStack(spacing: 10) {
                    metric("Beginning", hasBeginning, "1.circle")
                    metric("Middle", hasMiddle, "2.circle")
                    metric("Ending", hasEnding, "3.circle")
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    metric("Transitions", hasTransition, "arrow.triangle.swap")
                    metric("Voice/Sound", hasVoiceOrSound, "waveform")
                }

                VStack(spacing: 10) {
                    metric("Transitions", hasTransition, "arrow.triangle.swap")
                    metric("Voice/Sound", hasVoiceOrSound, "waveform")
                }
            }
        }
    }

    private var hasBeginning: Bool {
        capturedItems.contains { item in
            item.stageOrderIndex == 0
                || item.title.localizedCaseInsensitiveContains("begin")
                || item.title.localizedCaseInsensitiveContains("start")
                || item.title.localizedCaseInsensitiveContains("establish")
        }
    }

    private var hasMiddle: Bool {
        capturedItems.count >= max(2, items.count / 3)
    }

    private var hasEnding: Bool {
        capturedItems.contains { item in
            item.title.localizedCaseInsensitiveContains("ending")
                || item.title.localizedCaseInsensitiveContains("final")
                || item.title.localizedCaseInsensitiveContains("reflection")
                || item.kind == .transition && item.isBeforeLeaving
        }
    }

    private var hasTransition: Bool {
        capturedItems.contains { $0.kind == .transition }
    }

    private var hasVoiceOrSound: Bool {
        capturedItems.contains { $0.kind == .voice || $0.kind == .sound }
    }

    private func metric(_ title: String, _ isComplete: Bool, _ systemImage: String) -> some View {
        HStack(spacing: 10) {
            ArcMiniIconBadge(systemImage: isComplete ? "checkmark.circle" : systemImage, tint: isComplete ? ArcPalette.tint : ArcPalette.glowPrimary)
                .scaleEffect(0.82)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(isComplete ? "Covered" : "Gap")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isComplete ? ArcPalette.tint : ArcPalette.glowPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private enum CompletedShootSection: String, CaseIterable, Identifiable {
    case captured
    case skipped
    case missing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .captured:
            return "Captured"
        case .skipped:
            return "Skipped"
        case .missing:
            return "Missing"
        }
    }

    var systemImage: String {
        switch self {
        case .captured:
            return "checkmark.circle.fill"
        case .skipped:
            return "forward.circle.fill"
        case .missing:
            return "circle.dashed"
        }
    }

    var accent: Color {
        switch self {
        case .captured:
            return ArcPalette.tint
        case .skipped:
            return ArcPalette.glowSecondary
        case .missing:
            return ArcPalette.glowPrimary
        }
    }

    var emptyTitle: String {
        switch self {
        case .captured:
            return "No captured items"
        case .skipped:
            return "No skipped items"
        case .missing:
            return "No missing items"
        }
    }

    var emptyMessage: String {
        switch self {
        case .captured:
            return "Reopen this plan to continue field work."
        case .skipped:
            return "Skipped items will appear here."
        case .missing:
            return "Everything planned was captured."
        }
    }
}

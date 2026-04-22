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

    private var missingItems: [ShootPlanItem] {
        planItems.filter { !$0.isCaptured }
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
                            ArcMetricTile(title: "Missing", value: "\(plan?.missingCount ?? 0)", systemImage: "circle.dashed", accent: ArcPalette.glowPrimary)
                        }

                        VStack(spacing: 10) {
                            ArcMetricTile(title: "Planned", value: "\(planItems.count)", systemImage: "checklist", accent: ArcPalette.glowSecondary)
                            ArcMetricTile(title: "Captured", value: "\(plan?.capturedCount ?? 0)", systemImage: "checkmark.circle", accent: ArcPalette.tint)
                            ArcMetricTile(title: "Missing", value: "\(plan?.missingCount ?? 0)", systemImage: "circle.dashed", accent: ArcPalette.glowPrimary)
                        }
                    }
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
        case .missing:
            return missingItems
        }
    }

    private var completedSummary: String {
        guard let plan else {
            return "Completed"
        }

        if let completedAt = plan.completedAt {
            return "\(plan.capturedCount)/\(planItems.count) captured • \(completedAt.formatted(date: .abbreviated, time: .shortened))"
        }

        return "\(plan.capturedCount)/\(planItems.count) captured"
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

        sections.append("Coverage: \(plan.capturedCount)/\(planItems.count) captured")

        if !capturedItems.isEmpty {
            sections.append(
                (["Captured"] + capturedItems.map(itemExportLine))
                    .joined(separator: "\n")
            )
        }

        if !missingItems.isEmpty {
            sections.append(
                (["Missing"] + missingItems.map(itemExportLine))
                    .joined(separator: "\n")
            )
        }

        return sections.joined(separator: "\n\n")
    }

    private func itemExportLine(_ item: ShootPlanItem) -> String {
        "- \(item.title) (\(item.role)): \(item.guidance)"
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

                    Text("Role: \(item.role). \(item.guidance)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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

private enum CompletedShootSection: String, CaseIterable, Identifiable {
    case captured
    case missing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .captured:
            return "Captured"
        case .missing:
            return "Missing"
        }
    }

    var systemImage: String {
        switch self {
        case .captured:
            return "checkmark.circle.fill"
        case .missing:
            return "circle.dashed"
        }
    }

    var accent: Color {
        switch self {
        case .captured:
            return ArcPalette.tint
        case .missing:
            return ArcPalette.glowPrimary
        }
    }

    var emptyTitle: String {
        switch self {
        case .captured:
            return "No captured items"
        case .missing:
            return "No missing items"
        }
    }

    var emptyMessage: String {
        switch self {
        case .captured:
            return "Reopen this plan to continue field work."
        case .missing:
            return "Everything planned was captured."
        }
    }
}

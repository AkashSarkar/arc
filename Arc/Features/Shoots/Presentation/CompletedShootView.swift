import SwiftData
import SwiftUI

struct CompletedShootView: View {
    let location: ShootLocation

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isConfirmingDelete = false

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

    private var heroBadges: [ArcHeroBadge] {
        guard let plan else {
            return []
        }

        var badges = [
            ArcHeroBadge(label: plan.outputIntent.title, systemImage: "square.stack.3d.up"),
            ArcHeroBadge(label: "\(plan.capturedCount)/\(plan.items.count) captured", systemImage: "checkmark.circle")
        ]

        if let completedAt = plan.completedAt {
            badges.append(ArcHeroBadge(label: completedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock"))
        }

        return badges
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ArcHeroHeader(
                    systemImage: "checkmark.seal.fill",
                    title: location.name,
                    subtitle: "Completed field checklist and coverage summary.",
                    badges: heroBadges
                )

                ArcFeatureCard(accent: ArcPalette.glowSecondary) {
                    ArcFeatureTitle(
                        systemImage: "chart.bar.xaxis",
                        title: "Coverage Snapshot",
                        subtitle: nil,
                        accent: ArcPalette.glowSecondary
                    )

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            CompletedMetricTile(title: "Planned", value: "\(planItems.count)", accent: ArcPalette.glowSecondary)
                            CompletedMetricTile(title: "Captured", value: "\(plan?.capturedCount ?? 0)", accent: ArcPalette.tint)
                            CompletedMetricTile(title: "Missing", value: "\(plan?.missingCount ?? 0)", accent: ArcPalette.glowPrimary)
                        }

                        VStack(spacing: 12) {
                            CompletedMetricTile(title: "Planned", value: "\(planItems.count)", accent: ArcPalette.glowSecondary)
                            CompletedMetricTile(title: "Captured", value: "\(plan?.capturedCount ?? 0)", accent: ArcPalette.tint)
                            CompletedMetricTile(title: "Missing", value: "\(plan?.missingCount ?? 0)", accent: ArcPalette.glowPrimary)
                        }
                    }
                }

                ArcFeatureCard(accent: ArcPalette.tint) {
                    ArcFeatureTitle(
                        systemImage: "checklist.checked",
                        title: "Captured",
                        subtitle: capturedItems.isEmpty ? "No captured items are marked." : "\(capturedItems.count) captured items",
                        accent: ArcPalette.tint
                    )

                    if capturedItems.isEmpty {
                        Text("Reopen this shoot to continue field work.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(capturedItems) { item in
                            CompletedShotRow(
                                systemImage: "checkmark.circle.fill",
                                title: item.title,
                                subtitle: "Role: \(item.role). \(item.guidance)",
                                tint: ArcPalette.tint
                            )
                        }
                    }
                }

                if !missingItems.isEmpty {
                    ArcFeatureCard(accent: ArcPalette.glowPrimary) {
                        ArcFeatureTitle(
                            systemImage: "circle.dashed",
                            title: "Still Open",
                            subtitle: "\(missingItems.count) planned items were not captured.",
                            accent: ArcPalette.glowPrimary
                        )

                        ForEach(missingItems) { item in
                            CompletedShotRow(
                                systemImage: "circle.dashed",
                                title: item.title,
                                subtitle: "Role: \(item.role). \(item.guidance)",
                                tint: ArcPalette.glowPrimary
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(ArcSceneBackground())
        .navigationTitle("Completed")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    reopen()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel("Reopen shoot")

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete shoot")
            }
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

private struct CompletedMetricTile: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct CompletedShotRow: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ArcMiniIconBadge(systemImage: systemImage, tint: tint)

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

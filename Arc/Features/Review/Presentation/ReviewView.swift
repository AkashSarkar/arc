import SwiftUI

struct ReviewView: View {
    let location: ShootLocation

    private var plan: ShootPlan? {
        location.plan
    }

    private var planItems: [ShootPlanItem] {
        plan?.orderedItems ?? []
    }

    private var missingItems: [ShootPlanItem] {
        planItems.filter { !$0.isCaptured }
    }

    private var metrics: [ReviewMetricItem] {
        [
            ReviewMetricItem(title: "Planned", value: "\(planItems.count)", accent: ArcPalette.glowSecondary),
            ReviewMetricItem(title: "Captured", value: "\(plan?.capturedCount ?? 0)", accent: ArcPalette.tint),
            ReviewMetricItem(title: "Missing", value: "\(plan?.missingCount ?? 0)", accent: ArcPalette.glowPrimary)
        ]
    }

    private var heroSubtitle: String {
        if planItems.isEmpty {
            return "Generate a plan first, then use field mode to mark coverage."
        }

        if missingItems.isEmpty {
            return "Everything in the saved plan is covered."
        }

        return "Review the saved plan and close the remaining gaps before you leave."
    }

    private var heroBadges: [ArcHeroBadge] {
        guard let plan, !planItems.isEmpty else {
            return [ArcHeroBadge(label: "Plan needed", systemImage: "sparkles.rectangle.stack")]
        }

        return [
            ArcHeroBadge(label: plan.outputIntent.title, systemImage: "square.stack.3d.up"),
            ArcHeroBadge(label: "\(plan.capturedCount)/\(planItems.count) captured", systemImage: "checkmark.circle")
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ArcHeroHeader(
                    systemImage: "photo.on.rectangle.angled",
                    title: "Review Shoot",
                    subtitle: heroSubtitle,
                    badges: heroBadges
                ) {
                    ReviewLocationContextRow(
                        locationName: location.name,
                        outputIntentTitle: plan?.outputIntent.title
                    )
                }

                ArcFeatureCard(accent: ArcPalette.glowSecondary) {
                    ArcFeatureTitle(
                        systemImage: "chart.bar.xaxis",
                        title: "Coverage Snapshot",
                        subtitle: nil
                    )

                    if planItems.isEmpty {
                        Text("Save a plan for this location first. Coverage appears here once field mode is tracking the same shot list.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) {
                                ForEach(metrics) { metric in
                                    ReviewMetricTile(metric: metric)
                                }
                            }

                            VStack(spacing: 12) {
                                ForEach(metrics) { metric in
                                    ReviewMetricTile(metric: metric)
                                }
                            }
                        }

                        if let plan {
                            Text("Saved \(plan.createdAt.formatted(date: .abbreviated, time: .shortened)).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ArcFeatureCard(accent: ArcPalette.glowPrimary) {
                    ArcFeatureTitle(
                        systemImage: missingItems.isEmpty ? "checkmark.seal" : "circle.dashed",
                        title: missingItems.isEmpty ? "Coverage Complete" : "Still Open",
                        subtitle: nil
                    )

                    if planItems.isEmpty {
                        Text("Generate a plan, then mark items captured in field mode to review the same workflow here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if missingItems.isEmpty {
                        Text("All planned shots for \(location.name) are marked captured.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(missingItems, id: \.id) { item in
                            ReviewStepRow(
                                systemImage: "circle.dashed",
                                title: item.title,
                                subtitle: "Role: \(item.role). \(item.guidance)"
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(ArcSceneBackground())
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReviewLocationContextRow: View {
    let locationName: String
    let outputIntentTitle: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ArcPalette.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("Reviewing")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(locationName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if let outputIntentTitle {
                    Text(outputIntentTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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

private struct ReviewMetricItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let accent: Color
}

private struct ReviewMetricTile: View {
    let metric: ReviewMetricItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(metric.value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(metric.accent)
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

private struct ReviewStepRow: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ArcMiniIconBadge(systemImage: systemImage, tint: ArcPalette.glowPrimary)

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

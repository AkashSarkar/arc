import SwiftData
import SwiftUI

struct FieldView: View {
    let location: ShootLocation

    @Environment(\.modelContext) private var modelContext

    private var plan: ShootPlan? {
        guard let existingPlan = location.plan, existingPlan.isApprovedForField else {
            return nil
        }

        return existingPlan
    }

    private var planItems: [ShootPlanItem] {
        plan?.orderedItems ?? []
    }

    private var hasPlanItems: Bool {
        !planItems.isEmpty
    }

    private var completedCount: Int {
        plan?.capturedCount ?? 0
    }

    private var remainingCount: Int {
        max(planItems.count - completedCount, 0)
    }

    private var completionProgress: Double {
        plan?.completionProgress ?? 0
    }

    private var nextPendingItem: ShootPlanItem? {
        planItems.first(where: { !$0.isCaptured })
    }

    private var heroBadges: [ArcHeroBadge] {
        guard let plan, hasPlanItems else {
            return []
        }

        return [
            ArcHeroBadge(label: plan.outputIntent.title, systemImage: "square.stack.3d.up"),
            ArcHeroBadge(
                label: plan.shootWindowMode == .now ? "Now" : "Custom window",
                systemImage: "calendar.badge.clock"
            )
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ArcHeroHeader(
                    systemImage: "checklist.checked",
                    title: "Field Mode",
                    subtitle: hasPlanItems
                        ? "High contrast, quick decisions, minimal friction."
                        : "Generate a plan first, then use it as the field checklist.",
                    badges: heroBadges
                ) {
                    FieldLocationContextRow(locationName: location.name)

                    if hasPlanItems {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) {
                                FieldMetricTile(
                                    title: "Complete",
                                    value: "\(completedCount)/\(planItems.count)",
                                    accent: ArcPalette.tint
                                )

                                FieldMetricTile(
                                    title: "Remaining",
                                    value: "\(remainingCount)",
                                    accent: ArcPalette.glowPrimary
                                )
                            }

                            VStack(spacing: 12) {
                                FieldMetricTile(
                                    title: "Complete",
                                    value: "\(completedCount)/\(planItems.count)",
                                    accent: ArcPalette.tint
                                )

                                FieldMetricTile(
                                    title: "Remaining",
                                    value: "\(remainingCount)",
                                    accent: ArcPalette.glowPrimary
                                )
                            }
                        }

                        FieldProgressSection(
                            progress: completionProgress,
                            nextPendingTitle: nextPendingItem?.title
                        )

                        HStack(spacing: 12) {
                            Button(action: completeNextItem) {
                                Label(nextPendingItem == nil ? "All Done" : "Mark Next", systemImage: "checkmark.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FieldPrimaryButtonStyle())
                            .disabled(nextPendingItem == nil)

                            Button(action: resetChecklist) {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FieldSecondaryButtonStyle())
                        }
                    }
                }

                if hasPlanItems {
                    FieldChecklistCard(
                        items: planItems,
                        toggleItem: toggleItemCompletion
                    )

                    if let plan {
                        FieldGuidanceCard(
                            location: location,
                            outputIntentTitle: plan.outputIntent.title
                        )
                    }
                } else {
                    FieldPlanRequiredCard()
                }
            }
            .padding(20)
        }
        .background(ArcSceneBackground())
        .navigationTitle("Field")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggleItemCompletion(_ item: ShootPlanItem) {
        withAnimation(.easeInOut(duration: 0.18)) {
            item.isCaptured.toggle()
        }

        saveChanges()
    }

    private func completeNextItem() {
        guard let nextPendingItem else {
            return
        }

        toggleItemCompletion(nextPendingItem)
    }

    private func resetChecklist() {
        withAnimation(.easeInOut(duration: 0.18)) {
            for item in planItems {
                item.isCaptured = false
            }
        }

        saveChanges()
    }

    private func saveChanges() {
        try? modelContext.save()
    }
}

private struct FieldChecklistCard: View {
    let items: [ShootPlanItem]
    let toggleItem: (ShootPlanItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ArcFeatureTitle(
                systemImage: "checklist",
                title: "Checklist",
                subtitle: nil,
                accent: ArcPalette.tint
            )

            VStack(spacing: 12) {
                ForEach(items) { item in
                    Button {
                        toggleItem(item)
                    } label: {
                        FieldChecklistRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(ArcPalette.solidFieldSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct FieldGuidanceCard: View {
    let location: ShootLocation
    let outputIntentTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ArcFeatureTitle(
                systemImage: "eye.fill",
                title: "Reminders",
                subtitle: nil,
                accent: ArcPalette.glowSecondary
            )

            FieldGuidanceRow(
                systemImage: "sparkles.rectangle.stack",
                title: "Stay on brief",
                subtitle: "Keep the \(outputIntentTitle) set coherent while shooting \(location.name)."
            )

            FieldGuidanceRow(
                systemImage: "mountain.2.fill",
                title: "Open wide first",
                subtitle: "Anchor \(location.name) before moving into details."
            )

            FieldGuidanceRow(
                systemImage: "sun.haze.fill",
                title: "Protect highlights",
                subtitle: "Bias a touch darker if the sky or reflections start to clip."
            )

            FieldGuidanceRow(
                systemImage: "rectangle.portrait.and.arrow.right",
                title: "Grab one vertical cutaway",
                subtitle: "Leave with one detail or motion frame for the edit."
            )
        }
        .padding(20)
        .background(ArcPalette.solidFieldSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct FieldPlanRequiredCard: View {
    var body: some View {
        ArcFeatureCard(accent: ArcPalette.glowPrimary) {
            ArcFeatureTitle(
                systemImage: "sparkles.rectangle.stack",
                title: "No approved plan",
                subtitle: nil,
                accent: ArcPalette.glowPrimary
            )

            Text("Generate a draft, then tap Save Plan in planning before opening field mode.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FieldLocationContextRow: View {
    let locationName: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ArcPalette.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("Working at")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(locationName)
                    .font(.subheadline.weight(.semibold))
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

private struct FieldMetricTile: View {
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

private struct FieldProgressSection: View {
    let progress: Double
    let nextPendingTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Progress")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(progress.formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(ArcPalette.tint)
            }

            FieldProgressBar(progress: progress)

            Label(nextPendingTitle ?? "Checklist wrapped", systemImage: "camera.metering.center.weighted.average")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct FieldChecklistRow: View {
    let item: ShootPlanItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.isCaptured ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(item.isCaptured ? ArcPalette.tint : .secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)

                    Text(item.role)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ArcPalette.tint.opacity(0.14), in: Capsule())
                        .foregroundStyle(ArcPalette.tint)
                }

                Text(item.guidance)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(item.isCaptured ? ArcPalette.tint.opacity(0.45) : ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct FieldGuidanceRow: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ArcMiniIconBadge(systemImage: systemImage, tint: ArcPalette.glowSecondary)

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

private struct FieldProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let clampedProgress = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.10))

                Capsule()
                    .fill(ArcPalette.tint)
                    .frame(width: proxy.size.width * clampedProgress)
            }
        }
        .frame(height: 12)
    }
}

private struct FieldPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .foregroundStyle(Color.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ArcPalette.tint.opacity(configuration.isPressed ? 0.82 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

private struct FieldSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ArcPalette.elevatedSurface.opacity(configuration.isPressed ? 0.85 : 1))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

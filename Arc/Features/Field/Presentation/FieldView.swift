import SwiftUI

struct FieldView: View {
    let location: ShootLocation
    @State private var checklist: [FieldChecklistItem]

    init(location: ShootLocation) {
        self.location = location
        _checklist = State(initialValue: FieldChecklistItem.defaults(for: location))
    }

    private var completedCount: Int {
        checklist.filter(\ .isCompleted).count
    }

    private var remainingCount: Int {
        checklist.count - completedCount
    }

    private var completionProgress: Double {
        guard !checklist.isEmpty else { return 0 }
        return Double(completedCount) / Double(checklist.count)
    }

    private var nextPendingItem: FieldChecklistItem? {
        checklist.first(where: { !$0.isCompleted })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FieldHeroCard(
                    location: location,
                    progress: completionProgress,
                    completedCount: completedCount,
                    totalCount: checklist.count,
                    nextPendingTitle: nextPendingItem?.title
                )

                FieldQuickActionCard(
                    remainingCount: remainingCount,
                    hasPendingItems: nextPendingItem != nil,
                    completeNext: completeNextItem,
                    resetChecklist: resetChecklist
                )

                FieldChecklistCard(
                    items: checklist,
                    toggleItem: toggleItemCompletion
                )

                FieldGuidanceCard(location: location)
            }
            .padding(20)
        }
        .background(ArcSceneBackground())
        .navigationTitle("Field")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggleItemCompletion(_ item: FieldChecklistItem) {
        guard let index = checklist.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            checklist[index].isCompleted.toggle()
        }
    }

    private func completeNextItem() {
        guard let nextPendingItem else {
            return
        }

        toggleItemCompletion(nextPendingItem)
    }

    private func resetChecklist() {
        withAnimation(.easeInOut(duration: 0.18)) {
            for index in checklist.indices {
                checklist[index].isCompleted = false
            }
        }
    }
}

private struct FieldHeroCard: View {
    let location: ShootLocation
    let progress: Double
    let completedCount: Int
    let totalCount: Int
    let nextPendingTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ArcFeatureTitle(
                systemImage: "checklist.checked",
                title: "Field Mode",
                subtitle: "High contrast, quick decisions, minimal friction.",
                accent: ArcPalette.tint
            )

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline)

                    Text("\(completedCount) of \(totalCount) frames locked")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(progress.formatted(.percent.precision(.fractionLength(0))))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(ArcPalette.tint)
            }

            FieldProgressBar(progress: progress)

            HStack(spacing: 12) {
                FieldStatBadge(
                    systemImage: "camera.metering.center.weighted.average",
                    label: nextPendingTitle ?? "Checklist wrapped",
                    tone: ArcPalette.tint.opacity(0.18)
                )

                FieldStatBadge(
                    systemImage: "location.north.line",
                    label: location.latitude.formatted(.number.precision(.fractionLength(3))) + ", " + location.longitude.formatted(.number.precision(.fractionLength(3))),
                    tone: ArcPalette.glowSecondary.opacity(0.18)
                )
            }
        }
        .padding(22)
        .background(ArcPalette.solidFieldSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct FieldQuickActionCard: View {
    let remainingCount: Int
    let hasPendingItems: Bool
    let completeNext: () -> Void
    let resetChecklist: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ArcFeatureTitle(
                systemImage: "sun.max.fill",
                title: "Readable outdoors",
                subtitle: "Finish the next frame fast and keep the screen simple.",
                accent: ArcPalette.glowPrimary
            )

            HStack(spacing: 12) {
                Button(action: completeNext) {
                    Label(hasPendingItems ? "Mark Next Done" : "All Complete", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FieldPrimaryButtonStyle())
                .disabled(!hasPendingItems)

                Button(action: resetChecklist) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FieldSecondaryButtonStyle())
            }

            Text(remainingCount == 0 ? "Everything in this pass is covered." : "\(remainingCount) items still need a frame.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(ArcPalette.solidFieldSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct FieldChecklistCard: View {
    let items: [FieldChecklistItem]
    let toggleItem: (FieldChecklistItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ArcFeatureTitle(
                systemImage: "checklist",
                title: "Checklist",
                subtitle: "Large single-tap rows stay usable in motion.",
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ArcFeatureTitle(
                systemImage: "eye.fill",
                title: "Capture Guidance",
                subtitle: "A few reminders, without turning the phone into homework.",
                accent: ArcPalette.glowSecondary
            )

            FieldGuidanceRow(
                systemImage: "mountain.2.fill",
                title: "Open wide first",
                subtitle: "Start with one wide frame of \(location.name) before moving into details."
            )

            FieldGuidanceRow(
                systemImage: "sun.haze.fill",
                title: "Protect highlights",
                subtitle: "Bias a touch darker if the sky or reflections start to clip."
            )

            FieldGuidanceRow(
                systemImage: "rectangle.portrait.and.arrow.right",
                title: "Leave with one vertical cutaway",
                subtitle: "Grab one vertical detail or motion frame for the edit."
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

private struct FieldChecklistRow: View {
    let item: FieldChecklistItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(item.isCompleted ? ArcPalette.tint : .secondary)
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

                Text(item.subtitle)
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
                .stroke(item.isCompleted ? ArcPalette.tint.opacity(0.45) : ArcPalette.surfaceStroke, lineWidth: 1)
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

private struct FieldStatBadge: View {
    let systemImage: String
    let label: String
    let tone: Color

    var body: some View {
        Label(label, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(tone, in: Capsule())
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

private struct FieldChecklistItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let role: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, subtitle: String, role: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.role = role
        self.isCompleted = isCompleted
    }

    static func defaults(for location: ShootLocation) -> [FieldChecklistItem] {
        [
            FieldChecklistItem(
                title: "Establish the place",
                subtitle: "Take one wide frame that anchors \(location.name).",
                role: "Wide"
            ),
            FieldChecklistItem(
                title: "Lock the hero angle",
                subtitle: "Find the strongest main composition before the light shifts.",
                role: "Hero"
            ),
            FieldChecklistItem(
                title: "Capture a texture detail",
                subtitle: "Take one tighter frame to vary the set.",
                role: "Detail"
            ),
            FieldChecklistItem(
                title: "Grab a vertical cutaway",
                subtitle: "Shoot one vertical frame or motion clip.",
                role: "Motion"
            ),
            FieldChecklistItem(
                title: "Finish with a closer",
                subtitle: "Leave with one calmer ending frame.",
                role: "Closer"
            )
        ]
    }
}

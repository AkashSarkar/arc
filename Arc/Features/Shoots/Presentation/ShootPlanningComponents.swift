import SwiftUI

struct ShootPlanningControls: View {
    @Binding var outputIntent: OutputIntent
    @Binding var captureMedium: CaptureMedium
    @Binding var targetPlatform: TargetPlatform
    @Binding var stylePreset: CaptureStylePreset
    @Binding var shootWindowMode: ShootWindowMode
    @Binding var shootDate: Date
    @Binding var shootStartTime: Date
    @Binding var shootEndTime: Date

    var body: some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    ShootPlanFilterMenu(
                        systemImage: "square.stack.3d.up",
                        title: "Content",
                        selection: $outputIntent,
                        options: OutputIntent.allCases,
                        optionTitle: \.title
                    )

                    ShootPlanFilterMenu(
                        systemImage: "camera",
                        title: "Capture",
                        selection: $captureMedium,
                        options: CaptureMedium.allCases,
                        optionTitle: \.title
                    )
                }

                VStack(spacing: 10) {
                    ShootPlanFilterMenu(
                        systemImage: "square.stack.3d.up",
                        title: "Content",
                        selection: $outputIntent,
                        options: OutputIntent.allCases,
                        optionTitle: \.title
                    )

                    ShootPlanFilterMenu(
                        systemImage: "camera",
                        title: "Capture",
                        selection: $captureMedium,
                        options: CaptureMedium.allCases,
                        optionTitle: \.title
                    )
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    ShootPlanFilterMenu(
                        systemImage: "paperplane",
                        title: "Platform",
                        selection: $targetPlatform,
                        options: TargetPlatform.allCases,
                        optionTitle: \.title
                    )

                    ShootPlanFilterMenu(
                        systemImage: "camera.filters",
                        title: "Style",
                        selection: $stylePreset,
                        options: CaptureStylePreset.allCases,
                        optionTitle: \.title
                    )

                    ShootPlanFilterMenu(
                        systemImage: "calendar.badge.clock",
                        title: "Timing",
                        selection: $shootWindowMode,
                        options: ShootWindowMode.allCases,
                        optionTitle: \.title
                    )
                }

                VStack(spacing: 10) {
                    ShootPlanFilterMenu(
                        systemImage: "paperplane",
                        title: "Platform",
                        selection: $targetPlatform,
                        options: TargetPlatform.allCases,
                        optionTitle: \.title
                    )

                    ShootPlanFilterMenu(
                        systemImage: "camera.filters",
                        title: "Style",
                        selection: $stylePreset,
                        options: CaptureStylePreset.allCases,
                        optionTitle: \.title
                    )

                    ShootPlanFilterMenu(
                        systemImage: "calendar.badge.clock",
                        title: "Timing",
                        selection: $shootWindowMode,
                        options: ShootWindowMode.allCases,
                        optionTitle: \.title
                    )
                }
            }

            if shootWindowMode == .custom {
                ShootCustomWindowEditor(
                    shootDate: $shootDate,
                    shootStartTime: $shootStartTime,
                    shootEndTime: $shootEndTime
                )
            }
        }
    }
}

struct ShootNotesEditor: View {
    @Binding var notes: String
    var placeholder = "Mood, constraints, must-get shots, or anything the model should respect."

    var body: some View {
        ZStack(alignment: .topLeading) {
            if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 17)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $notes)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 150)
                .padding(12)
                .accessibilityLabel("Notes")
        }
        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

struct ShootDraftList: View {
    let items: [ShootDraftItem]
    let onEdit: (ShootDraftItem) -> Void
    let onDelete: (ShootDraftItem) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ShootDraftRow(
                    sequenceNumber: index + 1,
                    title: item.title,
                    role: item.role,
                    guidance: item.guidance,
                    onEdit: { onEdit(item) },
                    onDelete: { onDelete(item) }
                )
            }
        }
    }
}

struct CaptureItemList: View {
    let items: [CaptureItem]
    let onEdit: (CaptureItem) -> Void
    let onDelete: (CaptureItem) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ShootDraftRow(
                    sequenceNumber: index + 1,
                    title: item.title,
                    role: item.displayRoleTitle,
                    guidance: item.guidance,
                    onEdit: { onEdit(item) },
                    onDelete: { onDelete(item) }
                )
            }
        }
    }
}

struct ShootDraftPreviewList: View {
    let items: [ShootDraftItem]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ShootDraftRow(
                    sequenceNumber: index + 1,
                    title: item.title,
                    role: item.role,
                    guidance: item.guidance,
                    onEdit: nil,
                    onDelete: nil
                )
            }
        }
    }
}

struct ShootDraftRow: View {
    let sequenceNumber: Int
    let title: String
    let role: String
    let guidance: String
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Shot \(sequenceNumber)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ArcPalette.glowPrimary.opacity(0.15), in: Capsule())
                    .foregroundStyle(ArcPalette.glowPrimary)

                Text(title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(role)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ArcPalette.tint.opacity(0.14), in: Capsule())
                    .foregroundStyle(ArcPalette.tint)
            }

            Text(guidance)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if onEdit != nil || onDelete != nil {
                HStack(spacing: 8) {
                    if let onEdit {
                        Button("Edit", action: onEdit)
                            .buttonStyle(.glass)
                    }

                    if let onDelete {
                        Button("Delete", role: .destructive, action: onDelete)
                            .buttonStyle(.glass)
                    }
                }
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

struct ShootCustomWindowEditor: View {
    @Binding var shootDate: Date
    @Binding var shootStartTime: Date
    @Binding var shootEndTime: Date

    var body: some View {
        VStack(spacing: 10) {
            ShootCompactDatePickerRow(
                title: "Date",
                selection: $shootDate,
                displayedComponents: .date
            )

            ShootCompactDatePickerRow(
                title: "Start",
                selection: $shootStartTime,
                displayedComponents: .hourAndMinute
            )

            ShootCompactDatePickerRow(
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

struct ShootCompactDatePickerRow: View {
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

struct ShootPlanFilterMenu<Option: Identifiable & Hashable>: View {
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

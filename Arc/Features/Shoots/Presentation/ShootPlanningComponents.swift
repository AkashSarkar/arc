import SwiftUI

struct ShootPlanningControls: View {
    @Binding var outputIntent: OutputIntent
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
                        title: "Output",
                        selection: $outputIntent,
                        options: OutputIntent.allCases,
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
                        systemImage: "square.stack.3d.up",
                        title: "Output",
                        selection: $outputIntent,
                        options: OutputIntent.allCases,
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

    var body: some View {
        TextEditor(text: $notes)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 150)
            .padding(12)
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

struct ShootPlanItemList: View {
    let items: [ShootPlanItem]
    let onEdit: (ShootPlanItem) -> Void
    let onDelete: (ShootPlanItem) -> Void

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

struct ShootDraftRow: View {
    let sequenceNumber: Int
    let title: String
    let role: String
    let guidance: String
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

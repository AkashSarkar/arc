import SwiftData
import SwiftUI
import UIKit

struct CompletedShootView: View {
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isConfirmingDelete = false
    @State private var selectedSection: CompletedShootSection = .captured
    @State private var guideFileURL: URL?
    @State private var exportError: String?

    private var capturedItems: [CaptureItem] {
        trip.allItems.filter(\.isCaptured)
    }

    private var skippedItems: [CaptureItem] {
        trip.allItems.filter(\.isSkipped)
    }

    private var missingItems: [CaptureItem] {
        trip.allItems.filter { !$0.isResolved }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ArcCompactHeroHeader(
                    systemImage: "checkmark.seal.fill",
                    title: trip.title,
                    summary: completedSummary,
                    tint: ArcPalette.tint
                )

                ArcDenseCard(accent: ArcPalette.glowSecondary) {
                    ArcFeatureTitle(
                        systemImage: "chart.bar.xaxis",
                        title: "Coverage Snapshot",
                        subtitle: trip.isStorySafe ? "Must-get coverage is complete." : "\(trip.resolvedMustCount)/\(trip.mustCount) must-get items resolved.",
                        accent: ArcPalette.glowSecondary
                    )

                    CompletedCoverageStrip(trip: trip)
                }

                if let script = trip.artifacts.first(where: { $0.kind == .script }),
                   !script.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ArcDenseCard(accent: ArcPalette.tint) {
                        ArcFeatureTitle(
                            systemImage: "text.quote",
                            title: "Editing Script",
                            subtitle: "Generated from resolved field work.",
                            accent: ArcPalette.tint
                        )

                        Text(script.body)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Picker("Completed section", selection: $selectedSection) {
                    ForEach(CompletedShootSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)

                ArcDenseCard(accent: selectedSection.accent) {
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
                ShareLink(item: TripDocumentMapper.markdownExport(for: trip)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share summary")

                if let guideFileURL {
                    ShareLink(item: guideFileURL) {
                        Image(systemName: "doc.badge.arrow.up")
                    }
                    .accessibilityLabel("Share Arc guide")
                }

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
        .confirmationDialog("Delete this trip?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Trip", role: .destructive) {
                deleteTrip()
            }
            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("This removes the trip, stops, field guide, and export artifacts.")
        }
        .alert("Could Not Export Guide", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {
                exportError = nil
            }
        } message: {
            Text(exportError ?? "")
        }
        .onAppear {
            prepareGuideExport()
        }
    }

    private var selectedItems: [CaptureItem] {
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
        if let completedAt = trip.completedAt {
            return "\(trip.resolvedCount)/\(trip.allItems.count) resolved - \(completedAt.formatted(date: .abbreviated, time: .shortened))"
        }

        return "\(trip.resolvedCount)/\(trip.allItems.count) resolved"
    }

    private func prepareGuideExport() {
        do {
            _ = TripDocumentMapper.generateScriptArtifact(for: trip)
            let document = TripDocumentMapper.planDocument(from: trip, kind: .guide)
            let data = try ArcDocumentCodec.encode(document)
            let filename = "\(safeFilename(trip.title)).arcguide"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: [.atomic])
            guideFileURL = url
            try modelContext.save()
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func reopen() {
        trip.status = .active
        trip.completedAt = nil
        try? modelContext.save()
        dismiss()
    }

    private func deleteTrip() {
        modelContext.delete(trip)
        try? modelContext.save()
        dismiss()
    }

    private func safeFilename(_ title: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let scalars = title.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let cleaned = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Arc Guide" : cleaned
    }
}

private struct CompletedCoverageStrip: View {
    let trip: Trip

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                metric("Captured", "\(trip.capturedCount)")
                metric("Skipped", "\(trip.skippedCount)")
                metric("Missing", "\(trip.missingCount)")
                metric("Total", "\(trip.allItems.count)")
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metric("Captured", "\(trip.capturedCount)")
                metric("Skipped", "\(trip.skippedCount)")
                metric("Missing", "\(trip.missingCount)")
                metric("Total", "\(trip.allItems.count)")
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(ArcPalette.tint)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CompletedShotRow: View {
    let systemImage: String
    let item: CaptureItem
    let tint: Color

    private var thumbnailImage: UIImage? {
        guard let data = item.capturedPhotoData else {
            return nil
        }

        return UIImage(data: data)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)

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
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
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
            return "Reopen this trip to continue field work."
        case .skipped:
            return "Skipped items will appear here."
        case .missing:
            return "Everything planned was resolved."
        }
    }
}

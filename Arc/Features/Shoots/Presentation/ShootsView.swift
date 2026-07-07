import SwiftData
import SwiftUI

struct ShootsView: View {
    let aiService: any AIServicing
    let apiKeyStore: any APIKeyProviding
    let defaultAIConfiguration: AIConfiguration
    let locationEnricher: any LocationEnriching
    let referenceImageCache: any ReferenceImageCaching
    let locationEditorServices: LocationEditorServiceFactory

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var selectedSegment: ShootSegment = .active
    @State private var isPresentingNewShoot = false
    @State private var isPresentingImport = false
    @State private var isPresentingSettings = false
    @State private var routeToCreatedTrip = false
    @State private var createdTripID: UUID?
    @State private var pendingImportText = ""
    @State private var pendingImportDocument: ArcPlanDocument?
    @State private var importHandoffError: String?

    private var activeTrips: [Trip] {
        trips.filter { $0.status == .active || $0.status == .planning }
    }

    private var completedTrips: [Trip] {
        trips
            .filter { $0.status == .completed }
            .sorted {
                ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
            }
    }

    private var displayedTrips: [Trip] {
        switch selectedSegment {
        case .active:
            return activeTrips
        case .completed:
            return completedTrips
        }
    }

    var body: some View {
        List {
            Section {
                ShootsSegmentControl(
                    selection: $selectedSegment,
                    activeCount: activeTrips.count,
                    completedCount: completedTrips.count
                )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if displayedTrips.isEmpty {
                Section {
                    emptyState
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(displayedTrips) { trip in
                        switch selectedSegment {
                        case .active:
                            NavigationLink {
                                FieldView(
                                    trip: trip,
                                    aiService: aiService,
                                    locationEnricher: locationEnricher,
                                    referenceImageCache: referenceImageCache,
                                    locationEditorServices: locationEditorServices
                                )
                            } label: {
                                ShootsActiveRow(trip: trip)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(trip)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    finish(trip)
                                } label: {
                                    Label("Finish", systemImage: "checkmark.seal")
                                }
                                .tint(ArcPalette.tint)
                            }
                        case .completed:
                            NavigationLink {
                                CompletedShootView(trip: trip)
                            } label: {
                                ShootsCompletedRow(trip: trip)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(trip)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    reopen(trip)
                                } label: {
                                    Label("Reopen", systemImage: "arrow.counterclockwise")
                                }
                                .tint(ArcPalette.glowSecondary)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 1)
        .scrollContentBackground(.hidden)
        .background(ArcSceneBackground())
        .navigationTitle("Capture Plans")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isPresentingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Open settings")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        pendingImportText = ""
                        pendingImportDocument = nil
                        isPresentingImport = true
                    } label: {
                        Label("Import Existing Plan", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        isPresentingNewShoot = true
                    } label: {
                        Label("New Location Plan", systemImage: "mappin.and.ellipse")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add capture plan")
            }
        }
        .sheet(isPresented: $isPresentingNewShoot) {
            NewShootFlowView(
                aiService: aiService,
                locationEnricher: locationEnricher,
                referenceImageCache: referenceImageCache,
                locationEditorServices: locationEditorServices
            ) { trip in
                openCreatedTrip(trip)
            }
        }
        .sheet(isPresented: $isPresentingImport) {
            ImportPlanFlowView(
                aiService: aiService,
                initialText: pendingImportText,
                initialDocument: pendingImportDocument
            ) { trip in
                openCreatedTrip(trip)
                pendingImportText = ""
                pendingImportDocument = nil
            }
        }
        .sheet(isPresented: $isPresentingSettings) {
            NavigationStack {
                SettingsView(
                    apiKeyStore: apiKeyStore,
                    defaultAIConfiguration: defaultAIConfiguration
                )
            }
        }
        .navigationDestination(isPresented: $routeToCreatedTrip) {
            if let trip = createdTrip {
                FieldView(
                    trip: trip,
                    aiService: aiService,
                    locationEnricher: locationEnricher,
                    referenceImageCache: referenceImageCache,
                    locationEditorServices: locationEditorServices
                )
            } else {
                Text("Trip not found")
            }
        }
        .task {
            consumePendingImportIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                consumePendingImportIfNeeded()
            }
        }
        .onOpenURL { url in
            handleIncomingImportURL(url)
        }
        .alert("Could Not Import File", isPresented: Binding(
            get: { importHandoffError != nil },
            set: { if !$0 { importHandoffError = nil } }
        )) {
            Button("OK", role: .cancel) {
                importHandoffError = nil
            }
        } message: {
            Text(importHandoffError ?? "")
        }
    }

    private var createdTrip: Trip? {
        guard let createdTripID else {
            return nil
        }

        return trips.first { $0.id == createdTripID }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch selectedSegment {
        case .active:
            ArcDenseCard(accent: ArcPalette.tint) {
                ArcFeatureTitle(
                    systemImage: "square.and.arrow.down",
                    title: "Import a trip plan",
                    subtitle: "Paste or open the plan you already wrote."
                )

                Button {
                    pendingImportText = ""
                    pendingImportDocument = nil
                    isPresentingImport = true
                } label: {
                    Label("Import Plan", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)

                Button {
                    isPresentingNewShoot = true
                } label: {
                    Label("New Location Plan", systemImage: "mappin.and.ellipse")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
        case .completed:
            ArcDenseCard(accent: ArcPalette.glowSecondary) {
                ArcFeatureTitle(
                    systemImage: "archivebox",
                    title: "No completed plans yet",
                    subtitle: "Completed field guides will appear here."
                )
            }
        }
    }

    private func openCreatedTrip(_ trip: Trip) {
        selectedSegment = .active
        createdTripID = trip.id
        routeToCreatedTrip = true
    }

    private func finish(_ trip: Trip) {
        trip.status = .completed
        trip.completedAt = Date()
        _ = TripDocumentMapper.generateScriptArtifact(for: trip)
        try? modelContext.save()
        selectedSegment = .completed
    }

    private func reopen(_ trip: Trip) {
        trip.status = .active
        trip.completedAt = nil
        try? modelContext.save()
        selectedSegment = .active
    }

    private func delete(_ trip: Trip) {
        modelContext.delete(trip)
        try? modelContext.save()
    }

    private func consumePendingImportIfNeeded() {
        guard let text = ImportHandoff.consumePendingText() else {
            return
        }

        pendingImportText = text
        pendingImportDocument = nil
        isPresentingImport = true
    }

    private func handleIncomingImportURL(_ url: URL) {
        do {
            if let document = try ImportHandoff.readDocument(from: url) {
                pendingImportDocument = document
                pendingImportText = document.sourceText
            } else {
                pendingImportText = try ImportHandoff.readText(from: url)
                pendingImportDocument = nil
            }

            isPresentingImport = true
        } catch {
            importHandoffError = error.localizedDescription
        }
    }
}

private enum ShootSegment: String, CaseIterable, Identifiable {
    case active
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:
            return "Active"
        case .completed:
            return "Completed"
        }
    }

}

private struct ShootsSegmentControl: View {
    @Binding var selection: ShootSegment
    let activeCount: Int
    let completedCount: Int

    var body: some View {
        Picker("Plan status", selection: $selection) {
            Text("Active (\(activeCount))").tag(ShootSegment.active)
            Text("Completed (\(completedCount))").tag(ShootSegment.completed)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Capture plan status")
    }
}

private struct ShootsActiveRow: View {
    let trip: Trip

    private var progressText: String {
        "\(trip.resolvedCount)/\(trip.allItems.count)"
    }

    private var progress: Double {
        guard !trip.allItems.isEmpty else {
            return 0
        }

        return Double(trip.resolvedCount) / Double(trip.allItems.count)
    }

    private var nextLine: String {
        if let stage = trip.currentStage, let stop = trip.activeStop {
            return "\(stop.name) - \(stage.title)"
        }

        if let next = trip.allItems.first(where: { !$0.isResolved }),
           let stop = next.stage?.stop {
            return "\(stop.name) - \(next.title)"
        }

        return "Ready to complete"
    }

    private var detailLine: String {
        "\(trip.orderedStops.count) stops - \(trip.missingCount) remaining"
    }

    var body: some View {
        ArcDenseCard(accent: ArcPalette.tint) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(trip.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Label(nextLine, systemImage: "camera.viewfinder")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(detailLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ArcStatusPill(progressText, systemImage: "checkmark.circle", tint: ArcPalette.tint)
                    .monospacedDigit()
            }

            FieldProgressBar(progress: progress)
                .frame(height: 7)
        }
    }
}

private struct ShootsCompletedRow: View {
    let trip: Trip

    private var resolvedText: String {
        "\(trip.resolvedCount)/\(trip.allItems.count)"
    }

    private var detailLine: String {
        let skipped = trip.skippedCount == 0 ? "none skipped" : "\(trip.skippedCount) skipped"
        return "\(trip.capturedCount) captured - \(skipped)"
    }

    var body: some View {
        ArcDenseCard(accent: ArcPalette.glowSecondary) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(trip.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Label(completedSummary, systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(detailLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ArcStatusPill(resolvedText, systemImage: "checkmark.circle", tint: ArcPalette.glowSecondary)
                    .monospacedDigit()
            }
        }
    }

    private var completedSummary: String {
        guard let completedAt = trip.completedAt else {
            return "Completed"
        }

        return "Completed \(completedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

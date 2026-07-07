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

    private var heroBadges: [ArcHeroBadge] {
        [
            ArcHeroBadge(label: "\(activeTrips.count) active", systemImage: "checklist"),
            ArcHeroBadge(label: "\(completedTrips.count) completed", systemImage: "checkmark.seal")
        ]
    }

    var body: some View {
        List {
            Section {
                ArcHeroHeader(
                    systemImage: "camera.aperture",
                    title: "Capture Plans",
                    subtitle: rootSubtitle,
                    badges: heroBadges
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ShootsSegmentControl(
                    selection: $selectedSegment,
                    activeCount: activeTrips.count,
                    completedCount: completedTrips.count
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
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
                Section(selectedSegment.title) {
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
        .listStyle(.insetGrouped)
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
                        isPresentingNewShoot = true
                    } label: {
                        Label("New Location Plan", systemImage: "mappin.and.ellipse")
                    }

                    Button {
                        pendingImportText = ""
                        pendingImportDocument = nil
                        isPresentingImport = true
                    } label: {
                        Label("Import Existing Plan", systemImage: "square.and.arrow.down")
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

    private var rootSubtitle: String {
        if let nextTrip = activeTrips.first {
            if let stage = nextTrip.currentStage, let stop = nextTrip.activeStop {
                return "Next stage: \(stage.title) at \(stop.name)."
            }

            if let nextItem = nextTrip.allItems.first(where: { !$0.isResolved }), let stop = nextItem.stage?.stop {
                return "Next up: \(nextItem.title) at \(stop.name)."
            }
        }

        if !activeTrips.isEmpty {
            return "Open an active trip and keep the field guide moving."
        }

        return "Create or import a capture plan, then work it in the field."
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
            ArcFeatureCard(accent: ArcPalette.tint) {
                ArcFeatureTitle(
                    systemImage: "plus.circle",
                    title: "Start your first capture plan",
                    subtitle: "Pick a place or import a trip plan you already wrote."
                )

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        Button {
                            isPresentingNewShoot = true
                        } label: {
                            Label("New Location Plan", systemImage: "mappin.and.ellipse")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)

                        Button {
                            pendingImportText = ""
                            pendingImportDocument = nil
                            isPresentingImport = true
                        } label: {
                            Label("Import Plan", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                    }

                    VStack(spacing: 10) {
                        Button {
                            isPresentingNewShoot = true
                        } label: {
                            Label("New Location Plan", systemImage: "mappin.and.ellipse")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)

                        Button {
                            pendingImportText = ""
                            pendingImportDocument = nil
                            isPresentingImport = true
                        } label: {
                            Label("Import Plan", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
        case .completed:
            ArcFeatureCard(accent: ArcPalette.glowSecondary) {
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

    var systemImage: String {
        switch self {
        case .active:
            return "checklist"
        case .completed:
            return "checkmark.seal"
        }
    }
}

private struct ShootsSegmentControl: View {
    @Binding var selection: ShootSegment
    let activeCount: Int
    let completedCount: Int

    var body: some View {
        HStack(spacing: 8) {
            segmentButton(.active, count: activeCount)
            segmentButton(.completed, count: completedCount)
        }
        .padding(6)
        .background(ArcPalette.surfaceFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .glassEffect(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Capture plan status")
    }

    private func segmentButton(_ segment: ShootSegment, count: Int) -> some View {
        let isSelected = selection == segment
        let tint = segment == .active ? ArcPalette.tint : ArcPalette.glowSecondary

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selection = segment
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: segment.systemImage)
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: 1) {
                    Text(segment.title)
                        .font(.subheadline.weight(.semibold))

                    Text("\(count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(isSelected ? tint : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.16) : Color.clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.42) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ShootsActiveRow: View {
    let trip: Trip

    private var progressText: String {
        "\(trip.resolvedCount)/\(trip.allItems.count)"
    }

    private var nextTitle: String {
        if let stage = trip.currentStage {
            return stage.title
        }

        if let next = trip.allItems.first(where: { !$0.isResolved }) {
            return next.title
        }

        return "Ready to complete"
    }

    var body: some View {
        ArcDenseCard(accent: ArcPalette.tint) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(trip.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Label(nextTitle, systemImage: "camera.viewfinder")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ArcStatusPill(progressText, systemImage: "checkmark.circle", tint: ArcPalette.tint)
                    .monospacedDigit()
            }

            FieldProgressBar(progress: trip.allItems.isEmpty ? 0 : Double(trip.resolvedCount) / Double(trip.allItems.count))
                .frame(height: 7)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ArcStatusPill("\(trip.orderedStops.count) stops", systemImage: "map", tint: ArcPalette.glowSecondary)
                    ArcStatusPill("\(trip.allStages.count) stages", systemImage: "rectangle.stack", tint: ArcPalette.glowPrimary)
                    ArcStatusPill(trip.outputIntent.title, systemImage: "square.stack.3d.up")
                    ArcStatusPill(trip.captureMedium.title, systemImage: "camera", tint: ArcPalette.tint)
                    ArcStatusPill(trip.targetPlatform.title, systemImage: "paperplane", tint: ArcPalette.glowPrimary)
                }
            }
        }
    }
}

private struct ShootsCompletedRow: View {
    let trip: Trip

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
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(ArcPalette.glowSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ArcStatusPill("\(trip.capturedCount)/\(trip.allItems.count)", systemImage: "checkmark.circle", tint: ArcPalette.tint)
                    ArcStatusPill("\(trip.skippedCount) skipped", systemImage: "forward.end", tint: ArcPalette.glowSecondary)
                    ArcStatusPill(trip.targetPlatform.title, systemImage: "paperplane", tint: ArcPalette.tint)
                    ArcStatusPill(trip.stylePreset.title, systemImage: "camera.filters", tint: ArcPalette.glowPrimary)
                }
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

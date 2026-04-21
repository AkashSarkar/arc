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
    @Query(sort: \ShootLocation.createdAt, order: .reverse) private var locations: [ShootLocation]
    @State private var selectedSegment: ShootSegment = .active
    @State private var isPresentingNewShoot = false
    @State private var isPresentingSettings = false
    @State private var selectedShoot: ShootLocation?

    private var activeShoots: [ShootLocation] {
        locations.filter { $0.status == .active }
    }

    private var completedShoots: [ShootLocation] {
        locations
            .filter { $0.status == .completed }
            .sorted {
                ($0.plan?.completedAt ?? .distantPast) > ($1.plan?.completedAt ?? .distantPast)
            }
    }

    private var displayedShoots: [ShootLocation] {
        switch selectedSegment {
        case .active:
            return activeShoots
        case .completed:
            return completedShoots
        }
    }

    private var heroBadges: [ArcHeroBadge] {
        [
            ArcHeroBadge(label: "\(activeShoots.count) active", systemImage: "checklist"),
            ArcHeroBadge(label: "\(completedShoots.count) completed", systemImage: "checkmark.seal")
        ]
    }

    var body: some View {
        List {
            Section {
                ArcHeroHeader(
                    systemImage: "camera.aperture",
                    title: "Shoots",
                    subtitle: rootSubtitle,
                    badges: heroBadges
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                Picker("Shoot status", selection: $selectedSegment) {
                    ForEach(ShootSegment.allCases) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if displayedShoots.isEmpty {
                Section {
                    emptyState
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else {
                Section(selectedSegment.title) {
                    ForEach(displayedShoots) { location in
                        switch selectedSegment {
                        case .active:
                            NavigationLink {
                                FieldView(
                                    location: location,
                                    aiService: aiService,
                                    locationEnricher: locationEnricher,
                                    referenceImageCache: referenceImageCache,
                                    locationEditorServices: locationEditorServices
                                )
                            } label: {
                                ShootsActiveRow(location: location)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(location)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    finish(location)
                                } label: {
                                    Label("Finish", systemImage: "checkmark.seal")
                                }
                                .tint(ArcPalette.tint)
                            }
                        case .completed:
                            NavigationLink {
                                CompletedShootView(location: location)
                            } label: {
                                ShootsCompletedRow(location: location)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(location)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    reopen(location)
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
        .navigationTitle("Shoots")
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
                Button {
                    isPresentingNewShoot = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New shoot")
            }
        }
        .sheet(isPresented: $isPresentingNewShoot) {
            NewShootFlowView(
                aiService: aiService,
                locationEnricher: locationEnricher,
                referenceImageCache: referenceImageCache,
                locationEditorServices: locationEditorServices
            ) { location in
                selectedSegment = .active
                selectedShoot = location
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
        .navigationDestination(item: $selectedShoot) { location in
            FieldView(
                location: location,
                aiService: aiService,
                locationEnricher: locationEnricher,
                referenceImageCache: referenceImageCache,
                locationEditorServices: locationEditorServices
            )
        }
    }

    private var rootSubtitle: String {
        if let nextShoot = activeShoots.first, let nextItem = nextShoot.plan?.orderedItems.first(where: { !$0.isCaptured }) {
            return "Next up: \(nextItem.title) at \(nextShoot.name)."
        }

        if !activeShoots.isEmpty {
            return "Open an active checklist and keep the field workflow moving."
        }

        return "Create a shoot plan, then execute the checklist in field mode."
    }

    @ViewBuilder
    private var emptyState: some View {
        switch selectedSegment {
        case .active:
            ArcFeatureCard(accent: ArcPalette.tint) {
                ArcFeatureTitle(
                    systemImage: "plus.circle",
                    title: "Start your first shoot",
                    subtitle: "Pick a place, generate a plan, and land directly on the checklist."
                )

                Button {
                    isPresentingNewShoot = true
                } label: {
                    Text("New Shoot")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            }
        case .completed:
            ArcFeatureCard(accent: ArcPalette.glowSecondary) {
                ArcFeatureTitle(
                    systemImage: "archivebox",
                    title: "No completed shoots yet",
                    subtitle: "Finished field checklists will appear here."
                )
            }
        }
    }

    private func finish(_ location: ShootLocation) {
        guard let plan = location.plan else {
            return
        }

        plan.completedAt = Date()
        try? modelContext.save()
        selectedSegment = .completed
    }

    private func reopen(_ location: ShootLocation) {
        location.plan?.completedAt = nil
        try? modelContext.save()
        selectedSegment = .active
    }

    private func delete(_ location: ShootLocation) {
        modelContext.delete(location)
        try? modelContext.save()
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

private struct ShootsActiveRow: View {
    let location: ShootLocation

    private var plan: ShootPlan? {
        location.plan
    }

    private var progressText: String {
        guard let plan else {
            return "0/0"
        }

        return "\(plan.capturedCount)/\(plan.items.count)"
    }

    private var nextTitle: String {
        guard let plan else {
            return "Plan needed"
        }

        if let next = plan.orderedItems.first(where: { !$0.isCaptured }) {
            return next.title
        }

        return "Ready to finish"
    }

    var body: some View {
        ArcFeatureCard(accent: ArcPalette.tint) {
            HStack(alignment: .top, spacing: 14) {
                ArcMiniIconBadge(systemImage: "checklist", tint: ArcPalette.tint)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(location.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(progressText)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(ArcPalette.tint.opacity(0.14), in: Capsule())
                            .foregroundStyle(ArcPalette.tint)
                    }

                    Text(nextTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if let plan {
                        FieldProgressBar(progress: plan.completionProgress)
                            .frame(height: 8)

                        HStack(spacing: 8) {
                            Label(plan.outputIntent.title, systemImage: "square.stack.3d.up")
                            Label(plan.shootWindowMode.title, systemImage: "calendar.badge.clock")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct ShootsCompletedRow: View {
    let location: ShootLocation

    private var plan: ShootPlan? {
        location.plan
    }

    var body: some View {
        ArcFeatureCard(accent: ArcPalette.glowSecondary) {
            HStack(alignment: .top, spacing: 14) {
                ArcMiniIconBadge(systemImage: "checkmark.seal", tint: ArcPalette.glowSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text(location.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(completedSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let plan {
                        HStack(spacing: 8) {
                            Label("\(plan.capturedCount)/\(plan.items.count) captured", systemImage: "checkmark.circle")
                            Label(plan.outputIntent.title, systemImage: "square.stack.3d.up")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var completedSummary: String {
        guard let completedAt = plan?.completedAt else {
            return "Completed"
        }

        return "Finished \(completedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

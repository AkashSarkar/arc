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
    @State private var isPresentingImport = false
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
                    activeCount: activeShoots.count,
                    completedCount: completedShoots.count
                )
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
            ) { location in
                selectedSegment = .active
                selectedShoot = location
            }
        }
        .sheet(isPresented: $isPresentingImport) {
            ImportPlanFlowView(aiService: aiService) { location in
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
        if let nextShoot = activeShoots.first, let plan = nextShoot.plan {
            if let stage = plan.currentStage, plan.source == .importedText {
                return "Next stage: \(stage.title) in \(nextShoot.name)."
            }

            if let nextItem = plan.orderedItems.first(where: { !$0.isResolved }) {
                return "Next up: \(nextItem.title) at \(nextShoot.name)."
            }
        }

        if !activeShoots.isEmpty {
            return "Open an active capture plan and keep the field guide moving."
        }

        return "Create or import a capture plan, then work it in the field."
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
                    subtitle: "Completed shot lists will appear here."
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
    let location: ShootLocation

    private var plan: ShootPlan? {
        location.plan
    }

    private var progressText: String {
        guard let plan else {
            return "0/0"
        }

        return plan.source == .importedText ? "\(plan.resolvedCount)/\(plan.items.count)" : "\(plan.capturedCount)/\(plan.items.count)"
    }

    private var nextTitle: String {
        guard let plan else {
            return "Plan needed"
        }

        if let stage = plan.currentStage, plan.source == .importedText {
            return stage.title
        }

        if let next = plan.orderedItems.first(where: { !$0.isResolved }) {
            return next.title
        }

        return "Ready to complete"
    }

    var body: some View {
        ArcDenseCard(accent: ArcPalette.tint) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(location.name)
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

            if let plan {
                FieldProgressBar(progress: plan.source == .importedText ? plan.fieldCompletionProgress : plan.completionProgress)
                    .frame(height: 7)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ArcStatusPill(plan.outputIntent.title, systemImage: "square.stack.3d.up")
                        if plan.source == .importedText {
                            ArcStatusPill("Imported", systemImage: "square.and.arrow.down", tint: ArcPalette.glowSecondary)
                            ArcStatusPill("\(plan.fieldStages.count) stages", systemImage: "rectangle.stack", tint: ArcPalette.glowPrimary)
                        }
                        ArcStatusPill(plan.captureMedium.title, systemImage: "camera", tint: ArcPalette.tint)
                        ArcStatusPill(plan.targetPlatform.title, systemImage: "paperplane", tint: ArcPalette.glowPrimary)
                        ArcStatusPill(plan.stylePreset.title, systemImage: "camera.filters", tint: ArcPalette.glowSecondary)
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
        ArcDenseCard(accent: ArcPalette.glowSecondary) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(location.name)
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

            if let plan {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ArcStatusPill("\(plan.capturedCount)/\(plan.items.count)", systemImage: "checkmark.circle", tint: ArcPalette.tint)
                        if plan.source == .importedText {
                            ArcStatusPill("Imported", systemImage: "square.and.arrow.down", tint: ArcPalette.glowSecondary)
                        }
                        ArcStatusPill(plan.outputIntent.title, systemImage: "square.stack.3d.up", tint: ArcPalette.glowSecondary)
                        ArcStatusPill(plan.targetPlatform.title, systemImage: "paperplane", tint: ArcPalette.tint)
                        ArcStatusPill(plan.stylePreset.title, systemImage: "camera.filters", tint: ArcPalette.glowPrimary)
                    }
                }
            }
        }
    }

    private var completedSummary: String {
        guard let completedAt = plan?.completedAt else {
            return "Completed"
        }

        return "Completed \(completedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

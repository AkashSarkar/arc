import SwiftData
import SwiftUI

struct PlanView: View {
    let location: ShootLocation
    let locationEnricher: any LocationEnriching

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: PlanViewModel
    @State private var navigationTarget: PlanNavigationTarget?
    @State private var isRefreshingContext = false
    @State private var contextRefreshError: String?

    init(location: ShootLocation, aiService: any AIServicing, locationEnricher: any LocationEnriching) {
        self.location = location
        self.locationEnricher = locationEnricher
        _viewModel = State(initialValue: PlanViewModel(aiService: aiService, existingPlan: location.plan))
    }

    var body: some View {
        Form {
            Section {
                ArcHeroHeader(
                    systemImage: "sparkles.rectangle.stack",
                    title: "Plan Shoot",
                    subtitle: "Pick output and timing, then generate a draft for this location. Cached context is included when available."
                ) {
                    PlanLocationContextRow(locationName: location.name)

                    PlanPromptContextRow(
                        hasCachedContext: hasCachedContext,
                        lastEnrichedAt: location.lastEnrichedAt,
                        isRefreshing: isRefreshingContext,
                        onRefresh: {
                            Task { await refreshContext() }
                        },
                        onInspect: {
                            navigationTarget = .context
                        }
                    )

                    if let contextRefreshError {
                        Text(contextRefreshError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    HStack(spacing: 10) {
                        PlanFilterMenu(
                            systemImage: "square.stack.3d.up",
                            title: "Output",
                            selection: $viewModel.outputIntent,
                            options: OutputIntent.allCases,
                            optionTitle: \.title
                        )

                        PlanFilterMenu(
                            systemImage: "calendar.badge.clock",
                            title: "Timing",
                            selection: $viewModel.shootWindowMode,
                            options: ShootWindowMode.allCases,
                            optionTitle: \.title
                        )
                    }

                    if viewModel.shootWindowMode == .custom {
                        PlanCustomWindowEditor(
                            shootDate: $viewModel.shootDate,
                            shootStartTime: $viewModel.shootStartTime,
                            shootEndTime: $viewModel.shootEndTime
                        )
                    }

                    Text(planSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ArcFeatureCard {
                    ArcFeatureTitle(
                        systemImage: "note.text",
                        title: "Notes",
                        subtitle: nil
                    )

                    TextEditor(text: $viewModel.notes)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 140)
                        .padding(12)
                        .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
                        }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ArcFeatureCard(accent: ArcPalette.tint) {
                    Button {
                        Task {
                            await viewModel.generatePlan(for: location, modelContext: modelContext)
                        }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            Text(viewModel.isLoading ? "Generating..." : "Generate Plan")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(viewModel.isLoading)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    ArcFeatureCard(accent: .red) {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            if !viewModel.response.isEmpty {
                Section {
                    ArcFeatureCard(accent: ArcPalette.glowSecondary) {
                        ArcFeatureTitle(
                            systemImage: "text.alignleft",
                            title: "Draft Plan",
                            subtitle: "Saved for field and review."
                        )

                        Text(savedPlanSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("To edit this plan, change the notes, output, or timing above and generate again. The saved checklist updates in place.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(viewModel.response)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)

                        HStack(spacing: 10) {
                            Button {
                                navigationTarget = .field
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "checklist")
                                    Text("Open Field")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glassProminent)

                            Button {
                                navigationTarget = .review
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("Open Review")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(ArcSceneBackground())
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.shootStartTime) { _, _ in
            viewModel.ensureDefaultWindowTimes()
        }
        .navigationDestination(item: $navigationTarget) { target in
            switch target {
            case .field:
                FieldView(location: location)
            case .review:
                ReviewView(location: location)
            case .context:
                LocationContextView(location: location, locationEnricher: locationEnricher)
            }
        }
    }

    private var planSummary: String {
        if viewModel.shootWindowMode == .custom {
            return "\(viewModel.outputIntent.defaultShotCount) shots. \(viewModel.shootWindowSummary)"
        }

        return "\(viewModel.outputIntent.defaultShotCount) shots. Use current conditions."
    }

    private var savedPlanSummary: String {
        guard let createdAt = location.plan?.createdAt else {
            return "This draft is saved automatically when generation succeeds."
        }

        return "Saved automatically on \(createdAt.formatted(date: .abbreviated, time: .shortened))."
    }

    private var hasCachedContext: Bool {
        !location.enrichmentJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func refreshContext() async {
        isRefreshingContext = true
        contextRefreshError = nil
        defer { isRefreshingContext = false }

        let bundle = await locationEnricher.enrich(location: location, shootWindow: nil)

        do {
            let formattedJSON = try bundle.formattedJSONString()
            location.enrichmentJSON = formattedJSON
            location.lastEnrichedAt = bundle.generatedAt
            try modelContext.save()
        } catch {
            contextRefreshError = error.localizedDescription
        }
    }
}

private enum PlanNavigationTarget: String, Identifiable {
    case field
    case review
    case context

    var id: String { rawValue }
}

private struct PlanLocationContextRow: View {
    let locationName: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ArcPalette.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("Planning for")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(locationName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
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

private struct PlanPromptContextRow: View {
    let hasCachedContext: Bool
    let lastEnrichedAt: Date?
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onInspect: () -> Void

    private var title: String {
        hasCachedContext ? "Context ready" : "No context yet"
    }

    private var subtitle: String {
        if let lastEnrichedAt, hasCachedContext {
            return "Cached \(lastEnrichedAt.formatted(date: .abbreviated, time: .shortened)). Landmarks, weather, and timing will ground the prompt."
        }

        return "Fetch context to include landmarks, weather, and sun/moon timing in the prompt."
    }

    private var systemImage: String {
        hasCachedContext ? "checkmark.circle.fill" : "exclamationmark.circle"
    }

    private var tint: Color {
        hasCachedContext ? ArcPalette.tint : ArcPalette.glowPrimary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Button(action: onRefresh) {
                    HStack(spacing: 6) {
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(isRefreshing ? "Refreshing..." : (hasCachedContext ? "Refresh" : "Fetch Context"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .disabled(isRefreshing)

                if hasCachedContext {
                    Button(action: onInspect) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Inspect")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
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

private struct PlanCustomWindowEditor: View {
    @Binding var shootDate: Date
    @Binding var shootStartTime: Date
    @Binding var shootEndTime: Date

    var body: some View {
        VStack(spacing: 10) {
            PlanCompactDatePickerRow(
                title: "Date",
                selection: $shootDate,
                displayedComponents: .date
            )

            PlanCompactDatePickerRow(
                title: "Start",
                selection: $shootStartTime,
                displayedComponents: .hourAndMinute
            )

            PlanCompactDatePickerRow(
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

private struct PlanCompactDatePickerRow: View {
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

private struct PlanFilterMenu<Option: Identifiable & Hashable>: View {
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

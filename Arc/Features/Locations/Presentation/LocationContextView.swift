import SwiftData
import SwiftUI

struct LocationContextView: View {
    let location: ShootLocation

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: LocationContextViewModel

    init(location: ShootLocation, locationEnricher: any LocationEnriching) {
        self.location = location
        _viewModel = State(initialValue: LocationContextViewModel(location: location, locationEnricher: locationEnricher))
    }

    var body: some View {
        List {
            Section {
                ArcCompactHeroHeader(
                    systemImage: "map.circle.fill",
                    title: "Location Context",
                    summary: contextSummary
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ArcFeatureCard(accent: ArcPalette.tint) {
                    ArcFeatureTitle(
                        systemImage: "arrow.triangle.2.circlepath",
                        title: "Refresh Context",
                        subtitle: location.lastEnrichedAt == nil
                            ? "No cached context yet."
                            : "Last updated \(location.lastEnrichedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")"
                    )

                    Button {
                        Task {
                            await viewModel.refreshContext(for: location, modelContext: modelContext)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            Text(viewModel.isRefreshing ? "Refreshing..." : "Refresh Enrichment")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(viewModel.isRefreshing)
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

            if let contextBundle = viewModel.contextBundle {
                Section {
                    ArcFeatureCard {
                        ArcFeatureTitle(
                            systemImage: "sparkles",
                            title: "Highlights",
                            subtitle: nil
                        )

                        ForEach(contextBundle.highlights, id: \.self) { highlight in
                            Text(highlight)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    ArcFeatureCard(accent: ArcPalette.glowSecondary) {
                        ArcFeatureTitle(
                            systemImage: "server.rack",
                            title: "Provider Status",
                            subtitle: nil,
                            accent: ArcPalette.glowSecondary
                        )

                        ContextProviderStatusRow(title: "Overpass", status: contextBundle.providerStatuses.overpass)
                        ContextProviderStatusRow(title: "Wikipedia", status: contextBundle.providerStatuses.wikipedia)
                        ContextProviderStatusRow(title: "Flickr", status: contextBundle.providerStatuses.flickr)
                        ContextProviderStatusRow(title: "Open-Meteo", status: contextBundle.providerStatuses.openMeteo)
                        ContextProviderStatusRow(title: "Sun/Moon", status: contextBundle.providerStatuses.sunMoon)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            Section {
                ArcFeatureCard(accent: ArcPalette.glowPrimary) {
                    ArcFeatureTitle(
                        systemImage: "curlybraces.square",
                        title: "Cached JSON",
                        subtitle: viewModel.hasCachedContext ? "Saved on the location for reuse." : "Refresh context to generate JSON.",
                        accent: ArcPalette.glowPrimary
                    )

                    if viewModel.hasCachedContext {
                        Text(viewModel.jsonDump)
                            .font(.footnote.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    } else {
                        Text("No cached context is stored for this location yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ArcSceneBackground())
        .navigationTitle("Context")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadCachedContext(from: location)
        }
    }

    private var contextSummary: String {
        if let lastEnrichedAt = location.lastEnrichedAt {
            return "\(location.name) • \(lastEnrichedAt.formatted(date: .abbreviated, time: .shortened))"
        }

        return location.name
    }
}

private struct ContextProviderStatusRow: View {
    let title: String
    let status: LocationContextProviderStatus

    private var tint: Color {
        switch status.state {
        case .success:
            return ArcPalette.tint
        case .skipped:
            return ArcPalette.glowPrimary
        case .failed:
            return .red
        }
    }

    private var systemImage: String {
        switch status.state {
        case .success:
            return "checkmark.circle.fill"
        case .skipped:
            return "minus.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ArcMiniIconBadge(systemImage: systemImage, tint: tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(status.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

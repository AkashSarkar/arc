import SwiftUI

struct ShootInfoSheet: View {
    let location: ShootLocation
    let locationEnricher: any LocationEnriching
    let referenceImageCache: any ReferenceImageCaching
    let locationEditorServices: LocationEditorServiceFactory

    @Environment(\.dismiss) private var dismiss
    @State private var cacheStatus = ReferenceImageCacheResult(totalImages: 0, cachedImages: 0)
    @State private var isPresentingEditLocation = false

    private var plan: ShootPlan? {
        location.plan
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ArcHeroHeader(
                        systemImage: "info.circle.fill",
                        title: "Shoot Info",
                        subtitle: "Location, context, and offline reference status for the active checklist."
                    ) {
                        Label(location.name, systemImage: "mappin.and.ellipse")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    ArcFeatureCard(accent: ArcPalette.tint) {
                        ArcFeatureTitle(
                            systemImage: "map",
                            title: "Location",
                            subtitle: "\(location.latitude.formatted(.number.precision(.fractionLength(5)))), \(location.longitude.formatted(.number.precision(.fractionLength(5))))",
                            accent: ArcPalette.tint
                        )

                        Button {
                            isPresentingEditLocation = true
                        } label: {
                            Label("Edit Location", systemImage: "slider.horizontal.3")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    NavigationLink {
                        LocationContextView(location: location, locationEnricher: locationEnricher)
                    } label: {
                        ArcFeatureCard(accent: ArcPalette.glowSecondary) {
                            ArcFeatureTitle(
                                systemImage: "map.circle.fill",
                                title: "Context",
                                subtitle: contextSubtitle,
                                accent: ArcPalette.glowSecondary
                            )
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    ArcFeatureCard(accent: ArcPalette.glowPrimary) {
                        ArcFeatureTitle(
                            systemImage: "arrow.down.circle",
                            title: "References",
                            subtitle: referenceSubtitle,
                            accent: ArcPalette.glowPrimary
                        )

                        if let plan {
                            Text("\(plan.outputIntent.title) • \(plan.shootWindowSummary)")
                                .font(.caption)
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
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isPresentingEditLocation) {
                LocationEditorView(location: location, services: locationEditorServices) { draft in
                    location.name = draft.name
                    location.latitude = draft.coordinate.latitude
                    location.longitude = draft.coordinate.longitude
                }
            }
            .task(id: location.enrichmentJSON) {
                cacheStatus = referenceImageCache.cacheStatus(for: location)
            }
        }
    }

    private var contextSubtitle: String {
        if let lastEnrichedAt = location.lastEnrichedAt,
           !location.enrichmentJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Cached \(lastEnrichedAt.formatted(date: .abbreviated, time: .shortened)). Tap to refresh or inspect."
        }

        return "No cached context yet. Tap to fetch landmarks, weather, and sun/moon timing."
    }

    private var referenceSubtitle: String {
        guard cacheStatus.totalImages > 0 else {
            return "No offline reference images cached for this shoot."
        }

        return "\(cacheStatus.cachedImages) of \(cacheStatus.totalImages) cached for offline use."
    }
}

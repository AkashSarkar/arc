import SwiftUI

struct LocationDetailView: View {
    let location: ShootLocation
    let aiService: any AIServicing
    let locationEnricher: any LocationEnriching
    let locationEditorServices: LocationEditorServiceFactory

    @State private var isPresentingEditLocation = false

    private var heroBadges: [ArcHeroBadge] {
        var badges = [
            ArcHeroBadge(label: location.createdAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
        ]

        if let plan = location.plan, !plan.items.isEmpty {
            badges.append(ArcHeroBadge(label: "\(plan.items.count) shots planned", systemImage: "sparkles"))
        }

        if let lastEnrichedAt = location.lastEnrichedAt {
            badges.append(ArcHeroBadge(label: lastEnrichedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "map.circle"))
        }

        return badges
    }

    private var contextSubtitle: String {
        if let lastEnrichedAt = location.lastEnrichedAt {
            return "Context cached \(lastEnrichedAt.formatted(date: .abbreviated, time: .shortened))."
        }

        return "Refresh location context and inspect the cached JSON bundle."
    }

    private var planSubtitle: String {
        guard let plan = location.plan, !plan.items.isEmpty else {
            return "Generate a shot plan."
        }

        return "\(plan.items.count) shots saved."
    }

    private var fieldSubtitle: String {
        guard let plan = location.plan, !plan.items.isEmpty else {
            return "Generate a plan to create the checklist."
        }

        return "\(plan.capturedCount) of \(plan.items.count) captured."
    }

    private var reviewSubtitle: String {
        guard let plan = location.plan, !plan.items.isEmpty else {
            return "Review coverage after you plan and shoot."
        }

        if plan.missingCount == 0 {
            return "All planned shots are covered."
        }

        return "\(plan.missingCount) shots still open."
    }

    var body: some View {
        List {
            Section {
                ArcHeroHeader(
                    systemImage: "camera.aperture",
                    title: location.name,
                    subtitle: "Refine the pin, then move into plan, field, or review.",
                    badges: heroBadges
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                NavigationLink {
                    LocationContextView(location: location, locationEnricher: locationEnricher)
                } label: {
                    WorkflowCard(
                        title: "Context",
                        subtitle: contextSubtitle,
                        systemImage: "map.circle",
                        accent: ArcPalette.glowSecondary
                    )
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                NavigationLink {
                    PlanView(location: location, aiService: aiService)
                } label: {
                    WorkflowCard(
                        title: "Plan",
                        subtitle: planSubtitle,
                        systemImage: "sparkles.rectangle.stack",
                        accent: ArcPalette.tint
                    )
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                NavigationLink {
                    FieldView(location: location)
                } label: {
                    WorkflowCard(
                        title: "Field",
                        subtitle: fieldSubtitle,
                        systemImage: "checklist",
                        accent: ArcPalette.glowPrimary
                    )
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                NavigationLink {
                    ReviewView(location: location)
                } label: {
                    WorkflowCard(
                        title: "Review",
                        subtitle: reviewSubtitle,
                        systemImage: "photo.on.rectangle",
                        accent: ArcPalette.glowSecondary
                    )
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ArcSceneBackground())
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingEditLocation = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Edit location")
            }
        }
        .sheet(isPresented: $isPresentingEditLocation) {
            LocationEditorView(location: location, services: locationEditorServices) { draft in
                location.name = draft.name
                location.latitude = draft.coordinate.latitude
                location.longitude = draft.coordinate.longitude
            }
        }
    }
}

private struct WorkflowCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color

    var body: some View {
        ArcFeatureCard(accent: accent) {
            ArcFeatureTitle(
                systemImage: systemImage,
                title: title,
                subtitle: subtitle,
                accent: accent
            )
        }
    }
}

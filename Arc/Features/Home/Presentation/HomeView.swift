import SwiftData
import SwiftUI

struct HomeView: View {
    let makeAIService: (LLMProfile?) -> any AIServicing
    let apiKeyStore: any APIKeyProviding
    let defaultAIConfiguration: AIConfiguration
    let locationEnricher: any LocationEnriching
    let referenceImageCache: any ReferenceImageCaching
    let locationEditorServices: LocationEditorServiceFactory

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LLMProfile.createdAt, order: .forward) private var llmProfiles: [LLMProfile]

    private var activeProfile: LLMProfile? {
        llmProfiles.first(where: \.isActive)
    }

    private var aiService: any AIServicing {
        makeAIService(activeProfile)
    }

    var body: some View {
        NavigationStack {
            LocationListView(
                aiService: aiService,
                apiKeyStore: apiKeyStore,
                defaultAIConfiguration: defaultAIConfiguration,
                locationEnricher: locationEnricher,
                referenceImageCache: referenceImageCache,
                locationEditorServices: locationEditorServices
            )
        }
        .task(id: llmProfiles.count) {
            seedDefaultProfileIfNeeded()
        }
    }

    private func seedDefaultProfileIfNeeded() {
        var didChangeProfiles = false

        if llmProfiles.isEmpty {
            modelContext.insert(LLMProfile.seededDefault(from: defaultAIConfiguration))
            didChangeProfiles = true
        } else if activeProfile == nil, let firstProfile = llmProfiles.first {
            firstProfile.isActive = true
            didChangeProfiles = true
        }

        guard didChangeProfiles else {
            return
        }

        try? modelContext.save()
    }
}

#Preview {
    HomeView(
        makeAIService: { _ in PreviewAIService() },
        apiKeyStore: PreviewAPIKeyStore(),
        defaultAIConfiguration: AIConfiguration.fromBundle(),
        locationEnricher: PreviewLocationEnricher(),
        referenceImageCache: PreviewReferenceImageCache(),
        locationEditorServices: .live
    )
    .modelContainer(for: [ShootLocation.self, ShootPlan.self, ShootPlanItem.self, LLMProfile.self], inMemory: true)
}

private struct PreviewAIService: AIServicing {
    func generateShotPlan(for prompt: String) async throws -> String {
        "Preview response for: \(prompt)"
    }
}

private struct PreviewAPIKeyStore: APIKeyProviding {
    func apiKey(for account: String) throws -> String? {
        nil
    }

    func saveAPIKey(_ apiKey: String, for account: String) throws {
    }

    func deleteAPIKey(for account: String) throws {
    }
}

private struct PreviewLocationEnricher: LocationEnriching {
    func enrich(location: ShootLocation, shootWindow: DateInterval?) async -> LocationContextBundle {
        let start = shootWindow?.start ?? Date()
        let end = shootWindow?.end ?? start.addingTimeInterval(2 * 3600)
        return LocationContextBundle(
            generatedAt: Date(),
            location: .init(name: location.name, latitude: location.latitude, longitude: location.longitude),
            shootWindow: .init(start: start, end: end, label: "Preview window"),
            highlights: ["Preview enrichment context."],
            providerStatuses: .init(
                overpass: .success("Preview data."),
                wikipedia: .success("Preview data."),
                flickr: .skipped("No preview key."),
                openMeteo: .success("Preview forecast."),
                sunMoon: .success("Preview sun and moon data.")
            ),
            pointsOfInterest: [],
            wikipedia: nil,
            referenceImages: [],
            weather: nil,
            sunMoon: .init(
                sunrise: nil,
                sunset: nil,
                civilDawn: nil,
                civilDusk: nil,
                blueHourMorningStart: nil,
                blueHourMorningEnd: nil,
                goldenHourMorningStart: nil,
                goldenHourMorningEnd: nil,
                goldenHourEveningStart: nil,
                goldenHourEveningEnd: nil,
                blueHourEveningStart: nil,
                blueHourEveningEnd: nil,
                moonPhaseName: "Preview",
                moonIlluminationPercent: 0
            )
        )
    }
}
private struct PreviewReferenceImageCache: ReferenceImageCaching {
    func cacheReferenceImages(for location: ShootLocation) async -> ReferenceImageCacheResult {
        ReferenceImageCacheResult(totalImages: 0, cachedImages: 0)
    }

    func cacheStatus(for location: ShootLocation) -> ReferenceImageCacheResult {
        ReferenceImageCacheResult(totalImages: 0, cachedImages: 0)
    }
}

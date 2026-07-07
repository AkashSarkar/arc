import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class LocationContextViewModel {
    private let locationEnricher: any LocationEnriching

    var contextBundle: LocationContextBundle?
    var jsonDump: String
    var errorMessage: String?
    var isRefreshing = false

    init(location: Stop, locationEnricher: any LocationEnriching) {
        self.locationEnricher = locationEnricher
        self.jsonDump = location.enrichmentJSON
        self.contextBundle = LocationContextBundle.decode(from: location.enrichmentJSON)
    }

    var hasCachedContext: Bool {
        !jsonDump.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func refreshContext(for location: Stop, modelContext: ModelContext) async {
        isRefreshing = true
        errorMessage = nil

        defer { isRefreshing = false }

        let bundle = await locationEnricher.enrich(location: location, shootWindow: resolvedShootWindow(for: location))

        do {
            let formattedJSON = try bundle.formattedJSONString()
            location.enrichmentJSON = formattedJSON
            location.lastEnrichedAt = bundle.generatedAt
            try modelContext.save()

            contextBundle = bundle
            jsonDump = formattedJSON
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadCachedContext(from location: Stop) {
        jsonDump = location.enrichmentJSON
        contextBundle = LocationContextBundle.decode(from: location.enrichmentJSON)
    }

    private func resolvedShootWindow(for location: Stop) -> DateInterval? {
        guard let day = location.day, day.windowMode == .custom, let start = day.startTime else {
            return nil
        }
        let end = day.endTime ?? start.addingTimeInterval(2 * 3600)
        return DateInterval(start: start, end: max(end, start.addingTimeInterval(3600)))
    }
}

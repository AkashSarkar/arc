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

    init(location: ShootLocation, locationEnricher: any LocationEnriching) {
        self.locationEnricher = locationEnricher
        self.jsonDump = location.enrichmentJSON
        self.contextBundle = LocationContextBundle.decode(from: location.enrichmentJSON)
    }

    var hasCachedContext: Bool {
        !jsonDump.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func refreshContext(for location: ShootLocation, modelContext: ModelContext) async {
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

    func loadCachedContext(from location: ShootLocation) {
        jsonDump = location.enrichmentJSON
        contextBundle = LocationContextBundle.decode(from: location.enrichmentJSON)
    }

    private func resolvedShootWindow(for location: ShootLocation) -> DateInterval? {
        guard let plan = location.plan, plan.shootWindowMode == .custom else {
            return nil
        }

        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: plan.shootDate)
        let startTimeComponents = calendar.dateComponents([.hour, .minute], from: plan.shootStartTime)
        let endTimeComponents = calendar.dateComponents([.hour, .minute], from: plan.shootEndTime)

        let startComponents = DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: startTimeComponents.hour,
            minute: startTimeComponents.minute
        )
        let endComponents = DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: endTimeComponents.hour,
            minute: endTimeComponents.minute
        )

        guard let start = calendar.date(from: startComponents), let end = calendar.date(from: endComponents) else {
            return nil
        }

        return DateInterval(start: start, end: max(end, start.addingTimeInterval(3600)))
    }
}
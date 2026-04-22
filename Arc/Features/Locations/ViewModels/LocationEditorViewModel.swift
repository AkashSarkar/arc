import Foundation
import Observation

struct LocationDraftValue: Equatable {
    let name: String
    let coordinate: LocationCoordinate
}

@MainActor
@Observable
final class LocationEditorViewModel {
    let isEditing: Bool

    var name: String {
        didSet {
            handleNameChange()
        }
    }

    var searchQuery: String = "" {
        didSet {
            guard !isApplyingSearchQuery else {
                return
            }

            errorMessage = nil
            searchService.updateQuery(searchQuery)
        }
    }

    var latitudeText: String {
        didSet {
            handleManualCoordinateChange()
        }
    }

    var longitudeText: String {
        didSet {
            handleManualCoordinateChange()
        }
    }

    var suggestions: [LocationSearchSuggestion] = []
    var errorMessage: String?
    var isResolvingCurrentLocation = false
    var isResolvingSearchResult = false
    var isReverseGeocoding = false
    private(set) var selectedCoordinate: LocationCoordinate?
    private(set) var mapFocusCoordinate: LocationCoordinate?
    private(set) var mapFocusVersion = 0

    var navigationTitle: String {
        isEditing ? "Edit Location" : "Add Location"
    }

    var saveButtonTitle: String {
        isEditing ? "Update" : "Save"
    }

    var selectionTitle: String {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanName.isEmpty ? "Unnamed location" : cleanName
    }

    var hasLocationName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasSelectedCoordinate: Bool {
        selectedCoordinate != nil
    }

    var canConfirmSelection: Bool {
        hasLocationName &&
        hasSelectedCoordinate &&
        !isResolvingCurrentLocation &&
        !isResolvingSearchResult
    }

    var coordinateSummary: String {
        guard let selectedCoordinate else {
            return "No coordinates selected yet."
        }

        return "\(selectedCoordinate.latitude.formatted(.number.precision(.fractionLength(5)))), \(selectedCoordinate.longitude.formatted(.number.precision(.fractionLength(5))))"
    }

    private let currentLocationService: any CurrentLocationServicing
    private let searchService: any LocationSearchServicing
    private let reverseGeocodingService: any ReverseGeocodingServicing

    private var allowsAutomaticNameUpdates: Bool
    private var lastSuggestedName: String?
    private var hasLoadedDefaultLocation = false
    private var isApplyingCoordinateText = false
    private var isApplyingSuggestedName = false
    private var isApplyingSearchQuery = false
    private var reverseGeocodeTask: Task<Void, Never>?

    init(
        location: ShootLocation? = nil,
        currentLocationService: any CurrentLocationServicing,
        searchService: any LocationSearchServicing,
        reverseGeocodingService: any ReverseGeocodingServicing
    ) {
        let initialCoordinate = location.map {
            LocationCoordinate(latitude: $0.latitude, longitude: $0.longitude)
        }

        self.isEditing = location != nil
        self.name = location?.name ?? ""
        self.latitudeText = LocationEditorViewModel.formattedCoordinateText(location?.latitude)
        self.longitudeText = LocationEditorViewModel.formattedCoordinateText(location?.longitude)
        self.currentLocationService = currentLocationService
        self.searchService = searchService
        self.reverseGeocodingService = reverseGeocodingService
        self.selectedCoordinate = initialCoordinate
        self.mapFocusCoordinate = initialCoordinate
        self.allowsAutomaticNameUpdates = location?.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        self.lastSuggestedName = location?.name.trimmingCharacters(in: .whitespacesAndNewlines)

        self.searchService.onSuggestionsChanged = { [weak self] suggestions in
            self?.suggestions = suggestions
        }

        if self.selectedCoordinate != nil {
            self.mapFocusVersion = 1
        }
    }

    func loadDefaultLocationIfNeeded() async {
        guard !hasLoadedDefaultLocation else {
            return
        }

        hasLoadedDefaultLocation = true

        guard !isEditing, selectedCoordinate == nil else {
            return
        }

        await useCurrentLocation()
    }

    func useCurrentLocation() async {
        errorMessage = nil
        isResolvingCurrentLocation = true

        defer { isResolvingCurrentLocation = false }

        do {
            let coordinate = try await currentLocationService.requestCurrentLocation()
            applyCoordinate(coordinate, shouldFocusMap: true)
            scheduleReverseGeocoding(
                for: coordinate,
                forceNameUpdate: true,
                showErrors: true,
                delayNanoseconds: 0
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolveSuggestion(_ suggestion: LocationSearchSuggestion) async {
        errorMessage = nil
        isResolvingSearchResult = true

        defer { isResolvingSearchResult = false }

        do {
            let selection = try await searchService.resolveSuggestion(suggestion)
            applySelection(selection, forceNameUpdate: true)
            clearSearchInput()
            suggestions = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func searchUsingQuery() async {
        let cleanQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            return
        }

        errorMessage = nil
        isResolvingSearchResult = true

        defer { isResolvingSearchResult = false }

        do {
            let selection = try await searchService.search(query: cleanQuery)
            applySelection(selection, forceNameUpdate: true)
            clearSearchInput()
            suggestions = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateMapPin(to coordinate: LocationCoordinate) {
        guard coordinate != selectedCoordinate else {
            return
        }

        errorMessage = nil
        applyCoordinate(coordinate, shouldFocusMap: false)

        guard allowsAutomaticNameUpdates else {
            return
        }

        scheduleReverseGeocoding(for: coordinate, forceNameUpdate: false, showErrors: false)
    }

    func validatedDraft() -> LocationDraftValue? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            errorMessage = "Name is required."
            return nil
        }

        guard let coordinate = parsedCoordinate() else {
            return nil
        }

        errorMessage = nil
        return LocationDraftValue(name: cleanName, coordinate: coordinate)
    }

    private func handleNameChange() {
        guard !isApplyingSuggestedName else {
            return
        }

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            allowsAutomaticNameUpdates = true
            return
        }

        if cleanName != normalized(lastSuggestedName) {
            allowsAutomaticNameUpdates = false
        }
    }

    private func handleManualCoordinateChange() {
        guard !isApplyingCoordinateText else {
            return
        }

        errorMessage = nil

        guard let coordinate = tryParseCoordinate() else {
            return
        }

        guard coordinate != selectedCoordinate else {
            return
        }

        selectedCoordinate = coordinate
        mapFocusCoordinate = coordinate
        mapFocusVersion += 1
        scheduleReverseGeocoding(
            for: coordinate,
            forceNameUpdate: false,
            showErrors: false
        )
    }

    private func applySelection(_ selection: LocationSelection, forceNameUpdate: Bool) {
        applyCoordinate(selection.coordinate, shouldFocusMap: true)

        if let selectionName = normalized(selection.name) {
            applySuggestedName(selectionName, force: forceNameUpdate)
        } else {
            scheduleReverseGeocoding(
                for: selection.coordinate,
                forceNameUpdate: forceNameUpdate,
                showErrors: forceNameUpdate,
                delayNanoseconds: 0
            )
        }
    }

    private func applyCoordinate(_ coordinate: LocationCoordinate, shouldFocusMap: Bool) {
        reverseGeocodeTask?.cancel()
        selectedCoordinate = coordinate
        syncCoordinateFields(with: coordinate)

        if shouldFocusMap {
            mapFocusCoordinate = coordinate
            mapFocusVersion += 1
        }
    }

    private func syncCoordinateFields(with coordinate: LocationCoordinate) {
        isApplyingCoordinateText = true
        latitudeText = Self.formattedCoordinateText(coordinate.latitude)
        longitudeText = Self.formattedCoordinateText(coordinate.longitude)
        isApplyingCoordinateText = false
    }

    private func applySuggestedName(_ suggestedName: String, force: Bool) {
        guard force || allowsAutomaticNameUpdates || normalized(name) == nil else {
            return
        }

        isApplyingSuggestedName = true
        name = suggestedName
        isApplyingSuggestedName = false
        lastSuggestedName = suggestedName
        allowsAutomaticNameUpdates = true
    }

    private func scheduleReverseGeocoding(
        for coordinate: LocationCoordinate,
        forceNameUpdate: Bool,
        showErrors: Bool,
        delayNanoseconds: UInt64 = 350_000_000
    ) {
        reverseGeocodeTask?.cancel()
        isReverseGeocoding = true

        reverseGeocodeTask = Task { [weak self] in
            guard let self else {
                return
            }

            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }

            guard !Task.isCancelled else {
                self.finishReverseGeocodingForCancellation()
                return
            }

            await self.performReverseGeocoding(
                for: coordinate,
                forceNameUpdate: forceNameUpdate,
                showErrors: showErrors
            )
        }
    }

    private func performReverseGeocoding(
        for coordinate: LocationCoordinate,
        forceNameUpdate: Bool,
        showErrors: Bool
    ) async {
        defer { isReverseGeocoding = false }

        do {
            let suggestedName = try await reverseGeocodingService.reverseGeocodeName(for: coordinate)
            guard coordinate == selectedCoordinate else {
                return
            }

            if let suggestedName = normalized(suggestedName) {
                applySuggestedName(suggestedName, force: forceNameUpdate)
            } else if showErrors {
                errorMessage = "Couldn’t name this location automatically. Enter a name and save it manually."
            }
        } catch is CancellationError {
        } catch {
            if showErrors {
                errorMessage = "Couldn’t name this location automatically. Enter a name and save it manually."
            }
        }
    }

    private func finishReverseGeocodingForCancellation() {
        isReverseGeocoding = false
    }

    private func parsedCoordinate() -> LocationCoordinate? {
        let cleanLatitude = latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let latitude = Double(cleanLatitude), (-90 ... 90).contains(latitude) else {
            errorMessage = "Latitude must be between -90 and 90."
            return nil
        }

        let cleanLongitude = longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let longitude = Double(cleanLongitude), (-180 ... 180).contains(longitude) else {
            errorMessage = "Longitude must be between -180 and 180."
            return nil
        }

        let coordinate = LocationCoordinate(latitude: latitude, longitude: longitude)
        selectedCoordinate = coordinate
        mapFocusCoordinate = coordinate
        mapFocusVersion += 1
        return coordinate
    }

    private func tryParseCoordinate() -> LocationCoordinate? {
        let cleanLatitude = latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLongitude = longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let latitude = Double(cleanLatitude),
            let longitude = Double(cleanLongitude),
            (-90 ... 90).contains(latitude),
            (-180 ... 180).contains(longitude)
        else {
            return nil
        }

        return LocationCoordinate(latitude: latitude, longitude: longitude)
    }

    private func clearSearchInput() {
        isApplyingSearchQuery = true
        searchQuery = ""
        isApplyingSearchQuery = false
    }

    private static func formattedCoordinateText(_ value: Double?) -> String {
        guard let value else {
            return ""
        }

        return value.formatted(.number.precision(.fractionLength(6)))
    }

    private func normalized(_ value: String?) -> String? {
        guard let cleanValue = value?.trimmingCharacters(in: .whitespacesAndNewlines), !cleanValue.isEmpty else {
            return nil
        }

        return cleanValue
    }
}

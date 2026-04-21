import CoreLocation
import Foundation
import MapKit

struct LocationCoordinate: Equatable, Hashable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct LocationSelection: Equatable {
    let name: String?
    let coordinate: LocationCoordinate
}

struct LocationSearchSuggestion: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
}

enum LocationServiceError: LocalizedError {
    case locationServicesDisabled
    case permissionDenied
    case permissionRestricted
    case unableToDetermineLocation
    case searchReturnedNoResults
    case invalidSearchSelection

    var errorDescription: String? {
        switch self {
        case .locationServicesDisabled:
            return "Location Services are disabled on this device."
        case .permissionDenied:
            return "Allow location access to use your current GPS position."
        case .permissionRestricted:
            return "Location access is restricted on this device."
        case .unableToDetermineLocation:
            return "Could not determine a location right now."
        case .searchReturnedNoResults:
            return "No matching places were found."
        case .invalidSearchSelection:
            return "That search suggestion is no longer available."
        }
    }
}

@MainActor
protocol CurrentLocationServicing {
    func requestCurrentLocation() async throws -> LocationCoordinate
}

@MainActor
protocol LocationSearchServicing: AnyObject {
    var onSuggestionsChanged: (([LocationSearchSuggestion]) -> Void)? { get set }

    func updateQuery(_ query: String)
    func resolveSuggestion(_ suggestion: LocationSearchSuggestion) async throws -> LocationSelection
    func search(query: String) async throws -> LocationSelection
}

@MainActor
protocol ReverseGeocodingServicing {
    func reverseGeocodeName(for coordinate: LocationCoordinate) async throws -> String?
}

struct LocationEditorServiceFactory {
    let makeCurrentLocationService: @MainActor () -> any CurrentLocationServicing
    let makeSearchService: @MainActor () -> any LocationSearchServicing
    let makeReverseGeocodingService: @MainActor () -> any ReverseGeocodingServicing

    @MainActor
    static let live = LocationEditorServiceFactory(
        makeCurrentLocationService: { CurrentLocationService() },
        makeSearchService: { MapKitLocationSearchService() },
        makeReverseGeocodingService: { AppleReverseGeocodingService() }
    )
}

@MainActor
final class CurrentLocationService: NSObject, CurrentLocationServicing {
    private let manager: CLLocationManager
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<LocationCoordinate, Error>?

    init(manager: CLLocationManager = CLLocationManager()) {
        self.manager = manager
        super.init()
        self.manager.delegate = self
        self.manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestCurrentLocation() async throws -> LocationCoordinate {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .notDetermined:
            try await requestAuthorization()
        case .denied:
            throw LocationServiceError.permissionDenied
        case .restricted:
            throw LocationServiceError.permissionRestricted
        @unknown default:
            throw LocationServiceError.unableToDetermineLocation
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    private func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    private func resumeAuthorization(with result: Result<Void, Error>) {
        guard let authorizationContinuation else {
            return
        }

        self.authorizationContinuation = nil
        authorizationContinuation.resume(with: result)
    }

    private func resumeLocation(with result: Result<LocationCoordinate, Error>) {
        guard let locationContinuation else {
            return
        }

        self.locationContinuation = nil
        locationContinuation.resume(with: result)
    }
}

extension CurrentLocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            resumeAuthorization(with: .success(()))
        case .denied:
            resumeAuthorization(with: .failure(LocationServiceError.permissionDenied))
        case .restricted:
            resumeAuthorization(with: .failure(LocationServiceError.permissionRestricted))
        case .notDetermined:
            break
        @unknown default:
            resumeAuthorization(with: .failure(LocationServiceError.unableToDetermineLocation))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            resumeLocation(with: .failure(LocationServiceError.unableToDetermineLocation))
            return
        }

        resumeLocation(with: .success(LocationCoordinate(coordinate)))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                let resolvedError: any Error

                switch manager.authorizationStatus {
                case .authorizedAlways, .authorizedWhenInUse:
                    resolvedError = LocationServiceError.locationServicesDisabled
                case .denied:
                    resolvedError = LocationServiceError.permissionDenied
                case .restricted:
                    resolvedError = LocationServiceError.permissionRestricted
                case .notDetermined:
                    resolvedError = LocationServiceError.unableToDetermineLocation
                @unknown default:
                    resolvedError = LocationServiceError.unableToDetermineLocation
                }

                resumeLocation(with: .failure(resolvedError))
                return
            case .locationUnknown, .network:
                resumeLocation(with: .failure(LocationServiceError.unableToDetermineLocation))
                return
            default:
                break
            }
        }

        resumeLocation(with: .failure(error))
    }
}

@MainActor
final class MapKitLocationSearchService: NSObject, LocationSearchServicing {
    var onSuggestionsChanged: (([LocationSearchSuggestion]) -> Void)?

    private let completer: MKLocalSearchCompleter
    private var completionLookup: [UUID: MKLocalSearchCompletion] = [:]

    init(completer: MKLocalSearchCompleter = MKLocalSearchCompleter()) {
        self.completer = completer
        super.init()
        self.completer.delegate = self
        self.completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQuery(_ query: String) {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanQuery.isEmpty else {
            completionLookup.removeAll()
            onSuggestionsChanged?([])
            completer.queryFragment = ""
            return
        }

        completer.queryFragment = cleanQuery
    }

    func resolveSuggestion(_ suggestion: LocationSearchSuggestion) async throws -> LocationSelection {
        guard let completion = completionLookup[suggestion.id] else {
            throw LocationServiceError.invalidSearchSelection
        }

        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = [.address, .pointOfInterest]

        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else {
            throw LocationServiceError.searchReturnedNoResults
        }

        return selection(from: item, fallbackName: suggestion.title)
    }

    func search(query: String) async throws -> LocationSelection {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        request.resultTypes = [.address, .pointOfInterest]

        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else {
            throw LocationServiceError.searchReturnedNoResults
        }

        return selection(from: item)
    }

    private func selection(from item: MKMapItem, fallbackName: String? = nil) -> LocationSelection {
        let coordinate = LocationCoordinate(item.location.coordinate)
        let name = preferredName(for: item, fallbackName: fallbackName)
        return LocationSelection(name: name, coordinate: coordinate)
    }

    private func preferredName(for item: MKMapItem, fallbackName: String?) -> String? {
        let address = item.address
        let addressRepresentations = item.addressRepresentations
        let candidates = [
            item.name,
            address?.shortAddress,
            address?.fullAddress,
            addressRepresentations?.cityName,
            addressRepresentations?.regionName,
            fallbackName,
        ]

        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }
}

extension MapKitLocationSearchService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let suggestions = completer.results.map { completion -> LocationSearchSuggestion in
            let suggestion = LocationSearchSuggestion(
                id: UUID(),
                title: completion.title,
                subtitle: completion.subtitle
            )
            completionLookup[suggestion.id] = completion
            return suggestion
        }

        let validIDs = Set(suggestions.map(\.id))
        completionLookup = completionLookup.filter { validIDs.contains($0.key) }
        onSuggestionsChanged?(suggestions)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        completionLookup.removeAll()
        onSuggestionsChanged?([])
    }
}

@MainActor
final class AppleReverseGeocodingService: ReverseGeocodingServicing {
    func reverseGeocodeName(for coordinate: LocationCoordinate) async throws -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return nil
        }

        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<String?, Error>) in
            request.getMapItems(completionHandler: { mapItems, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let resolvedName = (mapItems ?? [])
                    .lazy
                    .compactMap(AppleReverseGeocodingService.preferredName)
                    .first
                continuation.resume(returning: resolvedName)
            })
        }
    }

    private static func preferredName(from item: MKMapItem) -> String? {
        let address = item.address
        let addressRepresentations = item.addressRepresentations
        let candidates: [String?] = [
            item.name,
            address?.shortAddress,
            address?.fullAddress,
            addressRepresentations?.cityName,
            addressRepresentations?.regionName,
        ]

        return candidates.compactMap(normalizedValue).first
    }

    private static func normalizedValue(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
import Foundation

protocol LocationEnriching {
    func enrich(location: ShootLocation, shootWindow: DateInterval?) async -> LocationContextBundle
}

struct LocationEnricher: LocationEnriching {
    private struct SourceResult<Value> {
        let value: Value
        let status: LocationContextProviderStatus
    }

    private let overpassClient: OverpassAPIClient
    private let wikipediaClient: WikipediaAPIClient
    private let flickrClient: FlickrAPIClient
    private let openMeteoClient: OpenMeteoAPIClient
    private let sunMoonCalculator: SunMoonCalculator

    init(
        overpassClient: OverpassAPIClient,
        wikipediaClient: WikipediaAPIClient,
        flickrClient: FlickrAPIClient,
        openMeteoClient: OpenMeteoAPIClient,
        sunMoonCalculator: SunMoonCalculator
    ) {
        self.overpassClient = overpassClient
        self.wikipediaClient = wikipediaClient
        self.flickrClient = flickrClient
        self.openMeteoClient = openMeteoClient
        self.sunMoonCalculator = sunMoonCalculator
    }

    func enrich(location: ShootLocation, shootWindow: DateInterval?) async -> LocationContextBundle {
        let locationName = location.name
        let latitude = location.latitude
        let longitude = location.longitude
        let resolvedShootWindow = shootWindow ?? defaultShootWindow(for: location)
        let generatedAt = Date()

        async let poiSource = loadSource(
            fallback: [LocationPointOfInterest](),
            operation: { try await overpassClient.fetchPointsOfInterest(latitude: latitude, longitude: longitude) },
            detail: { points in
                points.isEmpty ? "No POIs returned." : "\(points.count) nearby POIs cached."
            }
        )

        async let wikipediaSource = loadSource(
            fallback: Optional<LocationWikipediaSummary>.none,
            operation: { try await wikipediaClient.fetchLandmarkContext(latitude: latitude, longitude: longitude) },
            detail: { summary in
                if let summary {
                    return "Using nearby article \(summary.title)."
                }

                return "No nearby Wikipedia article found."
            }
        )

        async let flickrSource = loadSource(
            fallback: [LocationReferenceImage](),
            operation: { try await flickrClient.fetchReferenceImages(latitude: latitude, longitude: longitude) },
            detail: { images in
                images.isEmpty ? "No Flickr references returned." : "\(images.count) reference images cached."
            }
        )

        async let weatherSource = loadSource(
            fallback: Optional<LocationWeatherSummary>.none,
            operation: { try await openMeteoClient.fetchForecast(latitude: latitude, longitude: longitude, shootWindow: resolvedShootWindow) },
            detail: { weather in
                if let weather {
                    return weather.summary
                }

                return "No weather forecast returned."
            }
        )

        let sunMoon = sunMoonCalculator.calculate(
            latitude: latitude,
            longitude: longitude,
            date: resolvedShootWindow.start
        )
        let sunMoonStatus = LocationContextProviderStatus.success(
            sunMoon.sunrise == nil && sunMoon.sunset == nil
                ? "Sun events unavailable for this date and latitude."
                : "Sun and moon events calculated locally."
        )

        let poiResult = await poiSource
        let wikipediaResult = await wikipediaSource
        let flickrResult = await flickrSource
        let weatherResult = await weatherSource

        return LocationContextBundle(
            generatedAt: generatedAt,
            location: .init(
                name: locationName,
                latitude: latitude,
                longitude: longitude
            ),
            shootWindow: .init(
                start: resolvedShootWindow.start,
                end: resolvedShootWindow.end,
                label: shootWindowLabel(for: resolvedShootWindow)
            ),
            highlights: buildHighlights(
                locationName: locationName,
                pointsOfInterest: poiResult.value,
                wikipedia: wikipediaResult.value,
                referenceImages: flickrResult.value,
                weather: weatherResult.value,
                sunMoon: sunMoon
            ),
            providerStatuses: .init(
                overpass: poiResult.status,
                wikipedia: wikipediaResult.status,
                flickr: flickrResult.status,
                openMeteo: weatherResult.status,
                sunMoon: sunMoonStatus
            ),
            pointsOfInterest: poiResult.value,
            wikipedia: wikipediaResult.value,
            referenceImages: flickrResult.value,
            weather: weatherResult.value,
            sunMoon: sunMoon
        )
    }

    private func loadSource<Value>(
        fallback: Value,
        operation: () async throws -> Value,
        detail: (Value) -> String
    ) async -> SourceResult<Value> {
        do {
            let value = try await operation()
            return SourceResult(value: value, status: .success(detail(value)))
        } catch FlickrAPIClientError.missingAPIKey {
            return SourceResult(value: fallback, status: .skipped(FlickrAPIClientError.missingAPIKey.localizedDescription))
        } catch {
            return SourceResult(value: fallback, status: .failed(error.localizedDescription))
        }
    }

    private func defaultShootWindow(for location: ShootLocation) -> DateInterval {
        if let plan = location.plan, plan.shootWindowMode == .custom {
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

            let start = calendar.date(from: startComponents) ?? plan.shootDate
            let end = calendar.date(from: endComponents) ?? start.addingTimeInterval(2 * 3600)
            return DateInterval(start: start, end: max(end, start.addingTimeInterval(3600)))
        }

        let start = Date()
        return DateInterval(start: start, duration: 2 * 3600)
    }

    private func shootWindowLabel(for shootWindow: DateInterval) -> String {
        let dateText = shootWindow.start.formatted(date: .abbreviated, time: .omitted)
        let startText = shootWindow.start.formatted(date: .omitted, time: .shortened)
        let endText = shootWindow.end.formatted(date: .omitted, time: .shortened)
        return "\(dateText), \(startText) to \(endText)"
    }

    private func buildHighlights(
        locationName: String,
        pointsOfInterest: [LocationPointOfInterest],
        wikipedia: LocationWikipediaSummary?,
        referenceImages: [LocationReferenceImage],
        weather: LocationWeatherSummary?,
        sunMoon: LocationSunMoonSummary
    ) -> [String] {
        var highlights: [String] = []

        if !pointsOfInterest.isEmpty {
            highlights.append("\(pointsOfInterest.count) nearby POIs found around \(locationName).")
        }

        if let wikipedia {
            highlights.append("Nearest landmark context: \(wikipedia.title).")
        }

        if !referenceImages.isEmpty {
            highlights.append("\(referenceImages.count) Flickr references are available for visual research.")
        }

        if let weather {
            highlights.append("Weather: \(weather.summary)")
        }

        if let goldenHourStart = sunMoon.goldenHourEveningStart {
            highlights.append("Evening golden hour begins at \(goldenHourStart.formatted(date: .omitted, time: .shortened)).")
        } else if let sunrise = sunMoon.sunrise {
            highlights.append("Sunrise at \(sunrise.formatted(date: .omitted, time: .shortened)).")
        }

        highlights.append("Moon: \(sunMoon.moonPhaseName), \(Int(sunMoon.moonIlluminationPercent.rounded()))% illumination.")
        return highlights
    }
}

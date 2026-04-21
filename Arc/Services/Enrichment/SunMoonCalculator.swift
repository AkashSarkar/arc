import Foundation

struct SunMoonCalculator {
    func calculate(latitude: Double, longitude: Double, date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> LocationSunMoonSummary {
        let sunrise = solarEvent(date: date, latitude: latitude, longitude: longitude, zenithDegrees: 90.833, isSunrise: true, timeZone: timeZone)
        let sunset = solarEvent(date: date, latitude: latitude, longitude: longitude, zenithDegrees: 90.833, isSunrise: false, timeZone: timeZone)
        let civilDawn = solarEvent(date: date, latitude: latitude, longitude: longitude, zenithDegrees: 96, isSunrise: true, timeZone: timeZone)
        let civilDusk = solarEvent(date: date, latitude: latitude, longitude: longitude, zenithDegrees: 96, isSunrise: false, timeZone: timeZone)
        let morningSixDegrees = solarEvent(date: date, latitude: latitude, longitude: longitude, zenithDegrees: 84, isSunrise: true, timeZone: timeZone)
        let eveningSixDegrees = solarEvent(date: date, latitude: latitude, longitude: longitude, zenithDegrees: 84, isSunrise: false, timeZone: timeZone)

        let moonPhase = moonPhaseDetails(for: date)

        return LocationSunMoonSummary(
            sunrise: sunrise,
            sunset: sunset,
            civilDawn: civilDawn,
            civilDusk: civilDusk,
            blueHourMorningStart: civilDawn,
            blueHourMorningEnd: sunrise,
            goldenHourMorningStart: sunrise,
            goldenHourMorningEnd: morningSixDegrees,
            goldenHourEveningStart: eveningSixDegrees,
            goldenHourEveningEnd: sunset,
            blueHourEveningStart: sunset,
            blueHourEveningEnd: civilDusk,
            moonPhaseName: moonPhase.name,
            moonIlluminationPercent: moonPhase.illuminationPercent
        )
    }

    private func solarEvent(
        date: Date,
        latitude: Double,
        longitude: Double,
        zenithDegrees: Double,
        isSunrise: Bool,
        timeZone: TimeZone
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let longitudeHour = longitude / 15
        let approximateTime = isSunrise
            ? Double(dayOfYear) + ((6 - longitudeHour) / 24)
            : Double(dayOfYear) + ((18 - longitudeHour) / 24)

        let meanAnomaly = (0.9856 * approximateTime) - 3.289
        var trueLongitude = meanAnomaly
            + (1.916 * sin(Self.degreesToRadians(meanAnomaly)))
            + (0.020 * sin(Self.degreesToRadians(2 * meanAnomaly)))
            + 282.634
        trueLongitude = Self.normalizedDegrees(trueLongitude)

        var rightAscension = Self.radiansToDegrees(atan(0.91764 * tan(Self.degreesToRadians(trueLongitude))))
        rightAscension = Self.normalizedDegrees(rightAscension)

        let trueLongitudeQuadrant = floor(trueLongitude / 90) * 90
        let rightAscensionQuadrant = floor(rightAscension / 90) * 90
        rightAscension += trueLongitudeQuadrant - rightAscensionQuadrant
        rightAscension /= 15

        let sinDeclination = 0.39782 * sin(Self.degreesToRadians(trueLongitude))
        let cosDeclination = cos(asin(sinDeclination))

        let cosLocalHour = (
            cos(Self.degreesToRadians(zenithDegrees))
                - (sinDeclination * sin(Self.degreesToRadians(latitude)))
        ) / (cosDeclination * cos(Self.degreesToRadians(latitude)))

        if cosLocalHour > 1 || cosLocalHour < -1 {
            return nil
        }

        let localHourDegrees = isSunrise
            ? 360 - Self.radiansToDegrees(acos(cosLocalHour))
            : Self.radiansToDegrees(acos(cosLocalHour))
        let localHour = localHourDegrees / 15

        let localMeanTime = localHour + rightAscension - (0.06571 * approximateTime) - 6.622
        let universalTime = Self.normalizedHours(localMeanTime - longitudeHour)

        let offsetHours = Double(timeZone.secondsFromGMT(for: date)) / 3600
        let localTime = Self.normalizedHours(universalTime + offsetHours)

        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let localMidnight = calendar.date(from: components) else {
            return nil
        }

        return localMidnight.addingTimeInterval(localTime * 3600)
    }

    private func moonPhaseDetails(for date: Date) -> (name: String, illuminationPercent: Double) {
        let calendar = Calendar(identifier: .gregorian)
        let referenceComponents = DateComponents(
            calendar: calendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2000,
            month: 1,
            day: 6,
            hour: 18,
            minute: 14
        )
        let referenceDate = referenceComponents.date ?? date
        let synodicMonth = 29.530588853
        let daysSinceReference = date.timeIntervalSince(referenceDate) / 86_400
        var moonAge = daysSinceReference.truncatingRemainder(dividingBy: synodicMonth)
        if moonAge < 0 {
            moonAge += synodicMonth
        }

        let illumination = (1 - cos((2 * .pi * moonAge) / synodicMonth)) / 2
        let illuminationPercent = (illumination * 1000).rounded() / 10

        let phaseName: String
        switch moonAge {
        case 0..<1.84566:
            phaseName = "New Moon"
        case 1.84566..<5.53699:
            phaseName = "Waxing Crescent"
        case 5.53699..<9.22831:
            phaseName = "First Quarter"
        case 9.22831..<12.91963:
            phaseName = "Waxing Gibbous"
        case 12.91963..<16.61096:
            phaseName = "Full Moon"
        case 16.61096..<20.30228:
            phaseName = "Waning Gibbous"
        case 20.30228..<23.99361:
            phaseName = "Last Quarter"
        case 23.99361..<27.68493:
            phaseName = "Waning Crescent"
        default:
            phaseName = "New Moon"
        }

        return (phaseName, illuminationPercent)
    }

    private static func degreesToRadians(_ value: Double) -> Double {
        value * .pi / 180
    }

    private static func radiansToDegrees(_ value: Double) -> Double {
        value * 180 / .pi
    }

    private static func normalizedDegrees(_ value: Double) -> Double {
        var normalized = value.truncatingRemainder(dividingBy: 360)
        if normalized < 0 {
            normalized += 360
        }

        return normalized
    }

    private static func normalizedHours(_ value: Double) -> Double {
        var normalized = value.truncatingRemainder(dividingBy: 24)
        if normalized < 0 {
            normalized += 24
        }

        return normalized
    }
}
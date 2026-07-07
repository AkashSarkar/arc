import XCTest
@testable import Arc

nonisolated final class ImportCorpusTests: XCTestCase {
    func testImportCorpusFixtures() throws {
        let fixtures = try loadFixtures()
        XCTAssertGreaterThanOrEqual(fixtures.count, 8)

        for fixture in fixtures {
            let document = ImportedPlanParser.parseDocument(title: fixture.name, text: fixture.source)

            XCTAssertEqual(document.trip.days.count, fixture.expectations.expectedDayCount, fixture.name)
            XCTAssertGreaterThanOrEqual(document.stageCount, fixture.expectations.stageCount.min, fixture.name)
            XCTAssertLessThanOrEqual(document.stageCount, fixture.expectations.stageCount.max, fixture.name)

            for title in fixture.expectations.expectedStopTitles {
                XCTAssertTrue(document.stopTitles.contains(title), "\(fixture.name) missing stop \(title)")
            }

            for anchor in fixture.expectations.expectedGeoAnchors {
                XCTAssertTrue(document.geoAnchors.contains(anchor), "\(fixture.name) missing geo anchor \(anchor)")
            }

            for (title, kind) in fixture.expectations.expectedKinds {
                XCTAssertEqual(document.item(named: title)?.itemKind.rawValue, kind, "\(fixture.name) kind for \(title)")
            }

            for (title, priority) in fixture.expectations.expectedPriorities {
                XCTAssertEqual(document.item(named: title)?.priority.rawValue, priority, "\(fixture.name) priority for \(title)")
            }

            for title in fixture.expectations.expectedBeforeLeavingTitles {
                XCTAssertEqual(document.item(named: title)?.beforeLeaving, true, "\(fixture.name) before-leaving for \(title)")
            }
        }
    }

    private func loadFixtures() throws -> [CorpusFixture] {
        let bundle = Bundle(for: Self.self)
        // Synchronized groups flatten resources into the bundle root, so fall back there.
        // Note: urls(forResourcesWithExtension:subdirectory:) returns [] (not nil) for a missing subdirectory.
        let subdirectoryURLs = bundle.urls(forResourcesWithExtension: "md", subdirectory: "Fixtures/ImportCorpus") ?? []
        let rootURLs = bundle.urls(forResourcesWithExtension: "md", subdirectory: nil) ?? []
        let bundledURLs = subdirectoryURLs.isEmpty ? rootURLs : subdirectoryURLs
        let urls = bundledURLs.filter { sourceURL in
            FileManager.default.fileExists(
                atPath: sourceURL.deletingPathExtension().appendingPathExtension("json").path
            )
        }
        guard !urls.isEmpty else {
            XCTFail("Import corpus fixtures were not bundled.")
            return []
        }

        return try urls.sorted { $0.lastPathComponent < $1.lastPathComponent }.map { sourceURL in
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            let expectationURL = sourceURL.deletingPathExtension().appendingPathExtension("json")
            let data = try Data(contentsOf: expectationURL)
            return CorpusFixture(
                name: sourceURL.deletingPathExtension().lastPathComponent,
                source: source,
                expectations: try JSONDecoder().decode(CorpusExpectations.self, from: data)
            )
        }
    }
}

private nonisolated struct CorpusFixture {
    let name: String
    let source: String
    let expectations: CorpusExpectations
}

private nonisolated struct CorpusExpectations: Decodable {
    struct StageCount: Decodable {
        let min: Int
        let max: Int
    }

    let fixtureClass: String
    let expectedDayCount: Int
    let stageCount: StageCount
    let expectedStopTitles: [String]
    let expectedGeoAnchors: [String]
    let expectedKinds: [String: String]
    let expectedPriorities: [String: String]
    let expectedBeforeLeavingTitles: [String]
}

private nonisolated extension ArcPlanDocument {
    var stageCount: Int {
        trip.days.reduce(0) { count, day in
            count + day.stops.reduce(0) { $0 + $1.stages.count }
        }
    }

    var stopTitles: [String] {
        trip.days.flatMap { $0.stops.map(\.title) }
    }

    var geoAnchors: [String] {
        trip.days.flatMap { day in
            day.stops.compactMap { $0.geo?.sourceAnchor }
        }
    }

    func item(named title: String) -> ArcCaptureItemDocument? {
        trip.days.lazy
            .flatMap(\.stops)
            .flatMap(\.stages)
            .flatMap(\.items)
            .first { $0.title == title }
    }
}

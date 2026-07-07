import XCTest
@testable import Arc

nonisolated final class TripDocumentMapperTests: XCTestCase {
    @MainActor
    func testDocumentMapsToTripGraphAndGuideExport() throws {
        let document = ArcPlanDocument(
            generator: "ArcTests",
            sourceText: "# Kyoto",
            trip: ArcTripDocument(
                title: "Kyoto Field Test",
                summary: "A two-stop owner test.",
                brief: ArcTripBriefDocument(
                    outputIntent: OutputIntent.fullTravelVlog.rawValue,
                    captureMedium: CaptureMedium.hybrid.rawValue,
                    targetPlatform: TargetPlatform.youtube.rawValue,
                    stylePreset: CaptureStylePreset.cinematic.rawValue
                ),
                artifacts: [
                    ArcTripArtifactDocument(kind: .ideas, title: "Ideas", body: "Temple textures.")
                ],
                days: [
                    ArcShootDayDocument(
                        title: "Day 1",
                        stops: [
                            ArcStopDocument(
                                title: "Fushimi Inari",
                                placeName: "Fushimi Inari Taisha",
                                geo: ArcGeoDocument(
                                    lat: 34.9671,
                                    lon: 135.7727,
                                    resolved: true,
                                    sourceAnchor: "https://maps.google.com/?q=Fushimi+Inari"
                                ),
                                stages: [
                                    ArcStageDocument(
                                        title: "Arrival",
                                        goal: "Establish the shrine.",
                                        items: [
                                            ArcCaptureItemDocument(
                                                title: "Wide torii frame",
                                                guidance: "Hold 8 seconds.",
                                                itemKind: .shot,
                                                priority: .must,
                                                sourceLine: "- Wide torii frame"
                                            ),
                                            ArcCaptureItemDocument(
                                                title: "Ambient steps",
                                                guidance: "Record a clean bed.",
                                                itemKind: .sound,
                                                priority: .optional,
                                                sourceLine: "- sound: Ambient steps"
                                            )
                                        ]
                                    )
                                ]
                            )
                        ]
                    )
                ]
            )
        )

        let trip = TripDocumentMapper.trip(from: document)

        XCTAssertEqual(trip.title, "Kyoto Field Test")
        XCTAssertEqual(trip.orderedDays.count, 1)
        XCTAssertEqual(trip.orderedStops.first?.sourceGeoAnchor, "https://maps.google.com/?q=Fushimi+Inari")
        XCTAssertEqual(trip.orderedStops.first?.orderedStages.first?.goal, "Establish the shrine.")
        XCTAssertEqual(trip.allItems.count, 2)
        XCTAssertEqual(trip.allItems.first?.sourceLine, "- Wide torii frame")

        trip.status = .completed
        trip.completedAt = Date(timeIntervalSince1970: 1_800_000_000)
        trip.allItems.first?.isCaptured = true
        trip.allItems.first?.capturedAt = Date(timeIntervalSince1970: 1_800_000_010)
        trip.allItems.last?.isSkipped = true
        trip.allItems.last?.skippedAt = Date(timeIntervalSince1970: 1_800_000_020)

        let script = TripDocumentMapper.generateScriptArtifact(for: trip)
        XCTAssertEqual(script.kind, .script)
        XCTAssertTrue(script.body.contains("Wide torii frame"))

        let guide = try TripDocumentMapper.guideDocument(from: trip)
        XCTAssertEqual(guide.document.kind, .guide)
        XCTAssertNotNil(guide.document.execution)
        XCTAssertEqual(guide.document.execution?.coverage.total, 1)
        XCTAssertEqual(guide.document.execution?.coverage.storySafe, true)

        let data = try ArcDocumentCodec.encode(guide.document)
        let decoded = try ArcDocumentCodec.decodeGuide(from: data)
        XCTAssertEqual(decoded.document.kind, .guide)
        XCTAssertEqual(decoded.document.trip.days.first?.stops.first?.stages.first?.items.first?.title, "Wide torii frame")
    }
}

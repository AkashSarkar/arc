import XCTest
@testable import Arc

nonisolated final class ArcDocumentCodecTests: XCTestCase {
    func testPlanDocumentRoundTrips() throws {
        let document = ArcPlanDocument(
            generator: "ArcTests",
            sourceText: "# Test",
            trip: ArcTripDocument(
                title: "Test Trip",
                summary: "A simple story.",
                days: [
                    ArcShootDayDocument(
                        title: "Day 1",
                        stops: [
                            ArcStopDocument(
                                title: "Harbor",
                                geo: ArcGeoDocument(sourceAnchor: "https://maps.google.com/?q=Harbor"),
                                stages: [
                                    ArcStageDocument(
                                        title: "Arrival",
                                        goal: "Establish the harbor.",
                                        items: [
                                            ArcCaptureItemDocument(
                                                title: "Wide harbor frame",
                                                itemKind: .shot,
                                                priority: .must,
                                                sourceLine: "- Wide harbor frame"
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

        let data = try ArcDocumentCodec.encode(document)
        let decoded = try ArcDocumentCodec.decodePlan(from: data)

        XCTAssertEqual(decoded, document)
    }

    func testRejectsFutureSchemaVersion() throws {
        let json = """
        {
          "format": "arc.guide",
          "schemaVersion": 999,
          "kind": "plan",
          "generator": "ArcTests",
          "sourceText": "",
          "unparsedRemainder": [],
          "trip": {
            "title": "Future",
            "summary": "",
            "brief": { "outputIntent": "", "captureMedium": "", "targetPlatform": "", "stylePreset": "" },
            "artifacts": [],
            "days": [{ "title": "Day 1", "date": null, "stops": [] }]
          },
          "execution": null
        }
        """

        XCTAssertThrowsError(try ArcDocumentCodec.decodePlan(from: Data(json.utf8))) { error in
            XCTAssertEqual(error as? ArcDocumentError, .unsupportedSchemaVersion(999))
        }
    }

    func testIgnoresUnknownFields() throws {
        let json = """
        {
          "format": "arc.guide",
          "schemaVersion": 1,
          "kind": "plan",
          "generator": "ArcTests",
          "sourceText": "",
          "unparsedRemainder": [],
          "unknownTopLevel": "kept by future producers",
          "trip": {
            "title": "Unknown Fields",
            "summary": "",
            "brief": { "outputIntent": "", "captureMedium": "", "targetPlatform": "", "stylePreset": "" },
            "artifacts": [],
            "days": [
              {
                "title": "Day 1",
                "date": null,
                "stops": [
                  {
                    "title": "Stop",
                    "placeName": "Stop",
                    "geo": null,
                    "plannedArrival": null,
                    "plannedDeparture": null,
                    "newStopField": true,
                    "stages": [
                      {
                        "title": "Stage",
                        "goal": "",
                        "kind": "standard",
                        "items": [
                          {
                            "title": "Shot",
                            "guidance": "",
                            "itemKind": "shot",
                            "priority": "must",
                            "beforeLeaving": false,
                            "sourceLine": "- Shot",
                            "synthetic": false,
                            "futureItemField": 42
                          }
                        ]
                      }
                    ]
                  }
                ]
              }
            ]
          },
          "execution": null
        }
        """

        let decoded = try ArcDocumentCodec.decodePlan(from: Data(json.utf8))
        XCTAssertEqual(decoded.trip.title, "Unknown Fields")
        XCTAssertEqual(decoded.trip.days.first?.stops.first?.stages.first?.items.first?.title, "Shot")
    }
}

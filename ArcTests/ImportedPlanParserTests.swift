import XCTest
@testable import Arc

nonisolated final class ImportedPlanParserTests: XCTestCase {
    func testAFPTemplateParsesDaysStopsGeoKindsPrioritiesAndBeforeLeaving() {
        let text = """
        # Copenhagen — 2 Days

        ## Day 1: Old Town

        ### Stop: Nyhavn Harbor
        https://maps.google.com/?q=Nyhavn,+Copenhagen

        Arrival:
        - Establishing wide of the colored houses - hold 8s, include water in frame (must)
        - voice: First impression line to camera - one honest sentence (must)
        - sound: Ambient harbor audio - 30s clean (optional)

        Before you leave:
        - transition: Leaving transition - walk-away shot (must)

        ## Day 2: Waterfront

        9:00 AM - Reffen Street Food

        Food run:
        - Vendor flames close-up - handheld, expose for fire (must)
        """

        let document = ImportedPlanParser.parseDocument(title: "Fallback", text: text)

        XCTAssertEqual(document.trip.title, "Copenhagen — 2 Days")
        XCTAssertEqual(document.trip.days.count, 2)
        XCTAssertEqual(document.trip.days[0].stops.first?.title, "Nyhavn Harbor")
        XCTAssertEqual(document.trip.days[0].stops.first?.geo?.sourceAnchor, "https://maps.google.com/?q=Nyhavn,+Copenhagen")
        XCTAssertEqual(document.trip.days[1].stops.first?.geo?.sourceAnchor, "9:00 AM - Reffen Street Food")

        let items = document.allItems
        XCTAssertEqual(items.first(where: { $0.title == "First impression line to camera" })?.itemKind, .voice)
        XCTAssertEqual(items.first(where: { $0.title == "Ambient harbor audio" })?.priority, .optional)
        XCTAssertEqual(items.first(where: { $0.title == "Leaving transition" })?.beforeLeaving, true)
    }

    func testDraftMappingPreservesStageGoalsAndGeoAnchors() {
        let text = """
        # Kyoto

        ### Stop: Fushimi Inari
        https://maps.app.goo.gl/test

        Arrival:
        - Wide gates shot - low angle (must)
        """

        let draft = ImportedPlanParser.parse(title: "Kyoto", text: text)

        XCTAssertEqual(draft.stages.first?.sourceGeoAnchor, "https://maps.app.goo.gl/test")
        XCTAssertFalse(draft.stages.first?.goal.isEmpty ?? true)
    }
}

private nonisolated extension ArcPlanDocument {
    var allItems: [ArcCaptureItemDocument] {
        trip.days.flatMap { day in
            day.stops.flatMap { stop in
                stop.stages.flatMap(\.items)
            }
        }
    }
}

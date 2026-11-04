import Foundation
import CoreGraphics

// Story journeys: dotted routes with stops, each stop tied to one chapter.
//
// CONTENT RULE: every journey is unreviewed until checked by a person; Release builds
// hide unreviewed journeys. Stop positions are on a stylised map and are approximate.

struct JourneyStop: Hashable {
    let name: String
    let bookID: String
    let chapter: Int
    /// Grid position on the world map.
    let x: Double, y: Double
    let reference: String

    var grid: CGPoint { CGPoint(x: x, y: y) }
    var chapterLabel: String { "\(BibleCatalog.book(id: bookID)?.name ?? bookID) \(chapter)" }
}

struct Journey: Identifiable, Hashable, ReviewableContent {
    let id: String
    let name: String
    let summary: String
    let stops: [JourneyStop]
    let reference: String
    let source: String
    var note: String = ""
    var reviewed = false
}

enum JourneyData {
    static var visible: [Journey] { ContentGate.visible(all) }
    static func journey(id: String) -> Journey? { all.first { $0.id == id } }

    static let all: [Journey] = [
        Journey(
            id: "jonah", name: "Jonah's Journey",
            summary: "From Joppa onto the sea, into the great fish, and at last to Nineveh.",
            stops: [
                JourneyStop(name: "Joppa", bookID: "jonah", chapter: 1, x: 35.5, y: 74.2, reference: "Jonah 1:3"),
                JourneyStop(name: "The sea", bookID: "jonah", chapter: 2, x: 27.0, y: 65.5, reference: "Jonah 1:15–2:10"),
                JourneyStop(name: "Nineveh", bookID: "jonah", chapter: 3, x: 111.0, y: 31.0, reference: "Jonah 3:3"),
            ],
            reference: "Jonah 1–3", source: "Jonah 1–3 (ASV)",
            note: "Nineveh is placed in the Babylon & Persia region beside the Tigris; the map is stylised."),
        Journey(
            id: "paul-rome", name: "Paul's Voyage to Rome",
            summary: "Sailing by Sidon and Crete, shipwrecked on Melita, and brought at last to Rome.",
            stops: [
                JourneyStop(name: "Sidon", bookID: "acts", chapter: 27, x: 34.5, y: 34.0, reference: "Acts 27:3"),
                JourneyStop(name: "Fair Havens, Crete", bookID: "acts", chapter: 27, x: 27.5, y: 16.5, reference: "Acts 27:7–8"),
                JourneyStop(name: "Melita", bookID: "acts", chapter: 28, x: 21.5, y: 56.0, reference: "Acts 28:1"),
                JourneyStop(name: "Rome", bookID: "acts", chapter: 28, x: 9.0, y: 9.5, reference: "Acts 28:14–16"),
            ],
            reference: "Acts 27–28", source: "Acts 27–28 (ASV)",
            note: "Several stops share a chapter, so reading Acts 27 lights two stops and Acts 28 lights two. Positions follow the map's stylised coast, not real geography."),
        Journey(
            id: "galilee", name: "Jesus Around Galilee",
            summary: "Capernaum, the sea, Nazareth and Cana: places around the Sea of Galilee.",
            stops: [
                JourneyStop(name: "Capernaum", bookID: "mark", chapter: 1, x: 63.0, y: 23.0, reference: "Mark 1:21"),
                JourneyStop(name: "The sea", bookID: "mark", chapter: 4, x: 73.5, y: 12.0, reference: "Mark 4:1, 35–41"),
                JourneyStop(name: "Nazareth", bookID: "luke", chapter: 4, x: 62.0, y: 10.5, reference: "Luke 4:16"),
                JourneyStop(name: "Cana", bookID: "john", chapter: 2, x: 67.5, y: 8.2, reference: "John 2:1"),
            ],
            reference: "Mark 1, 4; Luke 4; John 2", source: "Mark 1, 4; Luke 4; John 2 (ASV)",
            note: "Stops are in the order given in the brief, not a single continuous trip in the Gospels."),
    ]
}

extension GameProgress {
    func isLit(_ stop: JourneyStop) -> Bool { readCount(stop.bookID, chapter: stop.chapter) > 0 }
    func litCount(_ journey: Journey) -> Int { journey.stops.filter(isLit).count }
    func isComplete(_ journey: Journey) -> Bool { litCount(journey) == journey.stops.count }
    /// Journey badges earned (every stop's chapter read).
    var completedJourneys: [Journey] { JourneyData.visible.filter(isComplete) }
}

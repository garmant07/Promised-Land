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
    /// Context card (unreviewed with the journey): what kind of place it was, what happened
    /// there (from the chapter), and what it may have looked like (only details the text gives).
    var place: String = ""
    var happened: String = ""
    var lookedLike: String = ""

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
                JourneyStop(name: "Joppa", bookID: "jonah", chapter: 1, x: 35.5, y: 74.2, reference: "Jonah 1:3",
                            place: "Port town",
                            happened: "Jonah rose up to flee unto Tarshish, went down to Joppa, found a ship going to Tarshish, paid the fare and went aboard.",
                            lookedLike: "A harbour where ships set sail for Tarshish (Jonah 1:3)."),
                JourneyStop(name: "The sea", bookID: "jonah", chapter: 2, x: 27.0, y: 65.5, reference: "Jonah 1:15–2:10",
                            place: "Open sea",
                            happened: "The sailors cast Jonah into the sea and it ceased from raging. The LORD prepared a great fish to swallow him, and he was in it three days and three nights, and prayed.",
                            lookedLike: "A mighty tempest on the sea, so that the ship was like to be broken (Jonah 1:4)."),
                JourneyStop(name: "Nineveh", bookID: "jonah", chapter: 3, x: 111.0, y: 31.0, reference: "Jonah 3:3",
                            place: "Great city",
                            happened: "Jonah went to Nineveh and cried, \u{201C}Yet forty days, and Nineveh shall be overthrown.\u{201D} The people believed God and turned from their evil way.",
                            lookedLike: "An exceeding great city, of three days' journey (Jonah 3:3)."),
            ],
            reference: "Jonah 1–3", source: "Jonah 1–3 (ASV)",
            note: "Nineveh is placed in the Babylon & Persia region beside the Tigris; the map is stylised. Context cards quote or closely follow the ASV; check wording."),
        Journey(
            id: "paul-rome", name: "Paul's Voyage to Rome",
            summary: "By Sidon and Myra to Fair Havens on Crete, through the storm, shipwrecked on Melita, and brought at last to Rome.",
            stops: [
                JourneyStop(name: "Sidon", bookID: "acts", chapter: 27, x: 34.5, y: 34.0, reference: "Acts 27:3",
                            place: "Port city",
                            happened: "The next day the ship touched at Sidon, and Julius the centurion treated Paul kindly and let him go to his friends to refresh himself.",
                            lookedLike: "A coastal city where Paul had friends (Acts 27:3)."),
                JourneyStop(name: "Myra", bookID: "acts", chapter: 27, x: 31.5, y: 24.5, reference: "Acts 27:5–6",
                            place: "City of Lycia",
                            happened: "Sailing across the sea off Cilicia and Pamphylia, they came to Myra. There the centurion found a ship of Alexandria sailing for Italy and put them on board.",
                            lookedLike: "A city where ships from Alexandria called on their way to Italy (Acts 27:6)."),
                JourneyStop(name: "Fair Havens, Crete", bookID: "acts", chapter: 27, x: 27.5, y: 16.5, reference: "Acts 27:7–12",
                            place: "Harbour",
                            happened: "Sailing slowly under the lee of Crete, they came to Fair Havens. Paul warned that the voyage would bring loss, but the master of the ship was believed instead.",
                            lookedLike: "A harbour near the city of Lasea, not commodious to winter in (Acts 27:8, 27:12)."),
                JourneyStop(name: "The storm", bookID: "acts", chapter: 27, x: 24.5, y: 38.0, reference: "Acts 27:14–44",
                            place: "Open sea",
                            happened: "A tempestuous wind called Euraquilo drove the ship for many days. Paul told them an angel of God had said all would be saved, and they all escaped safe to land.",
                            lookedLike: "Neither sun nor stars shone for many days, and no small tempest lay on them (Acts 27:20)."),
                JourneyStop(name: "Melita (Malta)", bookID: "acts", chapter: 28, x: 21.5, y: 56.0, reference: "Acts 28:1–10",
                            place: "Island",
                            happened: "Escaped from the shipwreck, they learned the island was called Melita. A viper fastened on Paul's hand and he shook it off and took no harm; he healed the father of Publius.",
                            lookedLike: "The islanders kindled a fire because of the rain and the cold (Acts 28:2)."),
                JourneyStop(name: "Rome", bookID: "acts", chapter: 28, x: 9.0, y: 9.5, reference: "Acts 28:14–31",
                            place: "Capital city",
                            happened: "The brethren came to meet them as far as the Market of Appius and the Three Taverns. Paul lived two whole years in his own hired dwelling, preaching the kingdom of God.",
                            lookedLike: "Paul was suffered to abide by himself with the soldier that guarded him (Acts 28:16)."),
            ],
            reference: "Acts 27–28", source: "Acts 27–28 (ASV)",
            note: "Six stops over two chapters: reading Acts 27 lights four and Acts 28 lights two. Myra and the storm are placed approximately on the stylised map. Melita is commonly identified with Malta; TODO: reviewer to confirm the wording."),
        Journey(
            id: "galilee", name: "Jesus Around Galilee",
            summary: "Capernaum, the sea, Nazareth and Cana: places around the Sea of Galilee.",
            stops: [
                JourneyStop(name: "Capernaum", bookID: "mark", chapter: 1, x: 63.0, y: 23.0, reference: "Mark 1:21",
                            place: "Town by the sea",
                            happened: "They went into Capernaum, and on the sabbath day he entered into the synagogue and taught, and they were astonished at his teaching.",
                            lookedLike: "A town with a synagogue (Mark 1:21)."),
                JourneyStop(name: "The sea", bookID: "mark", chapter: 4, x: 73.5, y: 12.0, reference: "Mark 4:1, 35–41",
                            place: "Sea of Galilee",
                            happened: "He taught a great multitude from a boat by the sea. That evening a great storm of wind arose; he rebuked the wind, and there was a great calm.",
                            lookedLike: "A great multitude on the land by the sea, and Jesus teaching from a boat (Mark 4:1)."),
                JourneyStop(name: "Nazareth", bookID: "luke", chapter: 4, x: 62.0, y: 10.5, reference: "Luke 4:16",
                            place: "Home town",
                            happened: "He came to Nazareth, where he had been brought up, went into the synagogue on the sabbath, and stood up to read from the book of the prophet Isaiah.",
                            lookedLike: "A city built on a hill, with a brow from which they would have thrown him down (Luke 4:29)."),
                JourneyStop(name: "Cana", bookID: "john", chapter: 2, x: 67.5, y: 8.2, reference: "John 2:1–11",
                            place: "Village",
                            happened: "There was a marriage in Cana of Galilee. Jesus turned water into wine: the beginning of his signs.",
                            lookedLike: "Six waterpots of stone set there for the Jews' manner of purifying (John 2:6)."),
            ],
            reference: "Mark 1, 4; Luke 4; John 2", source: "Mark 1, 4; Luke 4; John 2 (ASV)",
            note: "Stops are in the order given in the brief, not a single continuous trip in the Gospels. Context cards quote or closely follow the ASV; check wording."),
    ]

}

extension GameProgress {
    func isLit(_ stop: JourneyStop) -> Bool { readCount(stop.bookID, chapter: stop.chapter) > 0 }
    func litCount(_ journey: Journey) -> Int { journey.stops.filter(isLit).count }
    func isComplete(_ journey: Journey) -> Bool { litCount(journey) == journey.stops.count }
    /// Journey badges earned (every stop's chapter read).
    var completedJourneys: [Journey] { JourneyData.visible.filter(isComplete) }
}

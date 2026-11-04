import Testing
import Foundation
import CoreGraphics
@testable import Promised_Land

@MainActor
struct IslandGrowthTests {
    let day: TimeInterval = 86_400
    let start = Date(timeIntervalSince1970: 1_780_000_000)

    func buildings(_ island: Island) -> [Island.Item] {
        island.items.filter { if case .book = $0.source { true } else { false } }
    }

    @Test("Opening a book lays its foundations before any chapter is read")
    func openingLaysFoundations() {
        let island = Island.build(chapters: [], started: [("daniel", start)], quizzes: [], verses: [])
        let built = buildings(island)
        #expect(built.count == 1)
        #expect(built.first?.source == .book("daniel"))
        #expect(built.first?.progress == 0)
        #expect(built.first?.total == 12)
    }

    @Test("Every chapter read adds to the same building")
    func chaptersGrowOneBuilding() {
        let reads = (1...3).map { ("ruth", $0, start.addingTimeInterval(Double($0) * day)) }
        let island = Island.build(chapters: reads, quizzes: [], verses: [])
        let built = buildings(island)
        #expect(built.count == 1)
        #expect(built.first?.progress == 3)
        #expect(built.first?.total == 4)
        // Rereading doesn't add a second building.
        let again = Island.build(chapters: reads + [("ruth", 1, start.addingTimeInterval(9 * day))], quizzes: [], verses: [])
        #expect(buildings(again).count == 1)
        #expect(buildings(again).first?.progress == 3)
    }

    @Test("Buildings keep their places as more books are started")
    func placesAreStable() {
        let first = Island.build(chapters: [("ruth", 1, start)], quizzes: [], verses: [])
        let later = Island.build(chapters: [("ruth", 1, start), ("john", 1, start.addingTimeInterval(day))], quizzes: [], verses: [])
        #expect(first.items[0].gx == later.items[0].gx && first.items[0].gy == later.items[0].gy)
        #expect(buildings(later).count == 2)
        // A tile of open grass is left after each building.
        let a = buildings(later)[0].footprint, b = buildings(later)[1].footprint
        #expect(!a.intersects(b))
    }

    @Test("Short books get one floor per chapter; long books spread across five floors")
    func floors() {
        #expect(IslandBuildings.floors(total: 1) == 1)
        #expect(IslandBuildings.floors(total: 4) == 4)
        #expect(IslandBuildings.floors(total: 150) == 5)
        #expect(IslandBuildings.builtFloors(progress: 2, total: 4) == 2)
        // Every Psalm raises the building a little.
        #expect(IslandBuildings.builtFloors(progress: 31, total: 150) > IslandBuildings.builtFloors(progress: 30, total: 150))
    }

    @Test func styleGrowthKinds() {
        #expect(IslandBuildings.growth(of: .vineyard) == .rows)
        #expect(IslandBuildings.growth(of: .tents) == .settlement)
        #expect(IslandBuildings.growth(of: .temple) == .stories)
    }
}

import Testing
import Foundation
@testable import Promised_Land

/// Visiting a friend's or a group's island.
@MainActor
struct VisitedIslandTests {
    let hannah = MockFriendsService.samples[0]
    let group = MockGroupsService.sample

    @Test("The title says whose island it is")
    func titles() {
        #expect(VisitedIsland(owner: .friend(hannah)).title == "Hannah\u{2019}s Island")
        #expect(VisitedIsland(owner: .group(group)).title == "Sample Youth Group Island")
        #expect(VisitedIsland.friendTitle("Jerome") == "Jerome\u{2019}s Island")
        #expect(VisitedIsland.groupTitle("Riverside island") == "Riverside Island")
        #expect(VisitedIsland(owner: .friend(hannah)).isPreview && VisitedIsland(owner: .group(group)).isPreview)
    }

    @Test("Their island is built from their reads, the same way as yours (one renderer, their data)")
    func builtFromTheirReads() {
        let friend = VisitedIsland(owner: .friend(hannah)).build()
        let expected = Island.build(chapters: hannah.reads, quizzes: [], verses: [])
        #expect(friend.items == expected.items && friend.tiles == expected.tiles)
        #expect(!friend.items.isEmpty)
        // A group's island is everyone's reads together.
        let shared = VisitedIsland(owner: .group(group))
        #expect(shared.reads.count == group.members.reduce(0) { $0 + $1.reads.count })
        #expect(shared.build().plots.count >= friend.plots.count)
    }

    @Test("Inside a building: the book's chapters they've read")
    func inside() {
        let v = VisitedIsland(owner: .friend(hannah))
        #expect(v.chaptersRead("ruth") == Set(1...4))
        #expect(v.chaptersRead("revelation").isEmpty)
        #expect(v.notes.contains { $0.bookID == "ruth" })
        #expect(VisitedIsland(owner: .group(group)).notes.isEmpty) // group notes stay private
    }

    @Test("Your own island holds still while someone else's is open full screen")
    func coversCount() {
        let before = IslandCovers.shared.covered
        IslandCovers.shared.covered += 1
        #expect(IslandCovers.shared.covered == before + 1)
        IslandCovers.shared.covered -= 1
        #expect(IslandCovers.shared.covered == before)
    }
}

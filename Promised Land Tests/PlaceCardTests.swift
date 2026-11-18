import Testing
import Foundation
@testable import Promised_Land

@MainActor
struct PlaceCardTests {
    @Test("Place cards cover the Bible in order and by testament")
    func cardsCoverBible() throws {
        let document = try PlaceCardCatalog.load()
        #expect(document.cards.count == 66)
        #expect(document.cards.filter { $0.testament == "old" }.count == 39)
        #expect(document.cards.filter { $0.testament == "new" }.count == 27)

        for (index, book) in BibleCatalog.books.enumerated() {
            let card = try #require(document.cards.first { $0.order == index + 1 })
            #expect(card.book == book.name)
            #expect(card.testament == (book.testament == .old ? "old" : "new"))
        }
    }

    @Test("Every app Place has exactly one approved card name")
    func placeNamesMatchCards() throws {
        let document = try PlaceCardCatalog.load()
        for book in BibleCatalog.books {
            let matching = document.cards.filter { $0.book == book.name }
            #expect(matching.count == 1)
            #expect(PlaceData.spec(for: book.id).name == matching[0].name)
        }
    }

    @Test("Finished Place art slugs remove spaces and punctuation")
    func finishedArtSlugs() {
        #expect(PlaceCardCatalog.slug(for: "1 Samuel") == "1samuel")
        #expect(PlaceCardCatalog.slug(for: "Song of Songs") == "songofsongs")
        #expect(PlaceCardCatalog.slug(for: "3 John") == "3john")
        #expect(PlaceCardCatalog.finishedArtName(for: BibleCatalog.book(id: "3john")!) == "place_finished_3john")
    }
}

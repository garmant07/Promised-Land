import Foundation

nonisolated struct PlaceCard: Codable, Hashable, Identifiable, Sendable {
    let order: Int
    let testament: String
    let book: String
    let name: String
    let what: String
    let why: String

    var id: Int { order }
}

nonisolated struct PlaceCardDocument: Codable, Sendable {
    let version: Int
    let approved: String
    let note: String
    let cards: [PlaceCard]
}

enum PlaceCardCatalog {
    static let cards: [PlaceCard] = (try? load())?.cards ?? []

    static func load(from bundle: Bundle = .main) throws -> PlaceCardDocument {
        guard let url = bundle.url(forResource: "place_cards", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PlaceCardDocument.self, from: data)
    }

    static func card(for book: Book) -> PlaceCard? {
        cards.first { $0.order == (BibleCatalog.books.firstIndex { $0.id == book.id }.map { $0 + 1 } ?? 0) }
    }

    static func slug(for bookName: String) -> String {
        bookName.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func finishedArtName(for book: Book) -> String {
        "place_finished_\(slug(for: book.name))"
    }
}

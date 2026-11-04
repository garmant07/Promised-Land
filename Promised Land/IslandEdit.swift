import Foundation
import SwiftData

/// Where you've put a plot on your island (a book's plot, or the Library), saved when you
/// tap Done in edit mode. Plots without a saved place are laid out automatically.
@Model
final class PlacedItem {
    /// A book id, or `IslandPlacement.libraryKey`.
    var key: String = ""
    var x: Int = 0
    var y: Int = 0
    /// Quarter turns of the plot (0…3).
    var rotation: Int = 0
    /// True once you've dragged or turned it yourself; "Tidy up" leaves these alone.
    var moved: Bool = false
    var date: Date = Date.now

    init(key: String, x: Int, y: Int, rotation: Int = 0, moved: Bool = false) {
        self.key = key
        self.x = x
        self.y = y
        self.rotation = rotation
        self.moved = moved
    }
}

/// A plot's place on the island, as used when laying it out.
struct IslandPlacement: Equatable, Hashable {
    static let libraryKey = "feature:library"

    var x: Int
    var y: Int
    var rotation = 0
    var moved = false
}

extension ModelContext {
    /// Saves every plot's place (so unmoved plots stay exactly where they are), noting which
    /// ones you moved yourself.
    func savePlacements(_ placements: [String: IslandPlacement]) {
        let existing = (try? fetch(FetchDescriptor<PlacedItem>())) ?? []
        var byKey = Dictionary(existing.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        for (key, p) in placements {
            if let item = byKey.removeValue(forKey: key) {
                item.x = p.x; item.y = p.y; item.rotation = p.rotation; item.moved = p.moved
            } else {
                insert(PlacedItem(key: key, x: p.x, y: p.y, rotation: p.rotation, moved: p.moved))
            }
        }
        // Places for plots no longer in the draft (tidied up) are dropped, so they lay out again.
        for leftover in byKey.values { delete(leftover) }
        try? save()
    }
}

/// What the island view needs while editing.
struct IslandEditing {
    /// The plot picked (to turn it), if any.
    var selected: String?
    /// Dragging a plot: its key, the whole-tile offset so far, and whether the finger lifted.
    var onDrag: (String, Int, Int, Bool) -> Void
    /// Tapping a plot picks it; tapping elsewhere clears the pick.
    var onSelect: (String?) -> Void
}

extension Island.Item {
    /// The plot this item belongs to (a book id or the Library's key).
    var plotKey: String? {
        if case .feature(.library) = source { return IslandPlacement.libraryKey }
        return source.bookID
    }
}

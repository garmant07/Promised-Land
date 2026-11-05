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
    static let forestKey = "feature:forest"

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
    /// The plot this item belongs to (a book id, or the Library's or forest's key).
    var plotKey: String? {
        switch source {
        case .feature(.library): IslandPlacement.libraryKey
        case .forest: IslandPlacement.forestKey
        case .quiz(let b), .verse(let b), .place(let b, _), .flourish(let b): b
        case .extra(let id): "extra:\(id)"
        default: nil
        }
    }
}

/// Small decorations earned through reading streaks, placed freely in edit mode.
nonisolated enum ExtraKind: String, Sendable, CaseIterable, Codable {
    case path, fence, bench, tree, lamp

    var name: String {
        switch self {
        case .path: "Path"
        case .fence: "Fence"
        case .bench: "Bench"
        case .tree: "Tree"
        case .lamp: "Lamp"
        }
    }

    var symbol: String {
        switch self {
        case .path: "square.grid.2x2"
        case .fence: "rectangle.split.3x1"
        case .bench: "chair.lounge"
        case .tree: "tree.fill"
        case .lamp: "lightbulb.fill"
        }
    }

    var isTall: Bool { self == .tree || self == .lamp }
}

extension ModelContext {
    /// Saves the extras placed in edit mode (adding, moving and removing as needed).
    func saveExtras(_ extras: [PlacedExtraInfo]) {
        let existing = (try? fetch(FetchDescriptor<PlacedExtra>())) ?? []
        var byID = Dictionary(existing.map { ($0.uid, $0) }, uniquingKeysWith: { a, _ in a })
        for e in extras {
            if let row = byID.removeValue(forKey: e.id) {
                row.x = Double(e.x); row.y = Double(e.y); row.rotation = e.rotation; row.kind = e.kind.rawValue
            } else {
                let row = PlacedExtra(kind: e.kind, x: Double(e.x), y: Double(e.y), rotation: e.rotation)
                row.uid = e.id
                insert(row)
            }
        }
        for gone in byID.values { delete(gone) }
        try? save()
    }
}

/// A placed extra, as the island builder needs it.
struct PlacedExtraInfo: Hashable {
    let id: String
    let kind: ExtraKind
    let x: CGFloat
    let y: CGFloat
    var rotation = 0
}

/// One-time move to the growing-Places island (layout version 2). Places are worked out from the
/// reading history, so every existing reader's island rebuilds itself; this only tidies the
/// saved positions from the old plot layout: positions the app pinned automatically are dropped
/// (so Places are laid out loosely), positions you chose yourself are kept if they still fit,
/// and the "already seen" markers are reset so the first look is quiet rather than a huge reveal.
enum IslandMigration {
    static let versionKey = "island.layoutVersion"
    static let current = 2

    static func run(_ context: ModelContext, defaults: UserDefaults = .standard) {
        guard defaults.integer(forKey: versionKey) < current else { return }
        let placed = (try? context.fetch(FetchDescriptor<PlacedItem>())) ?? []
        for item in placed where !item.moved { context.delete(item) }
        let kept = placed.filter(\.moved)
        if !kept.isEmpty {
            let reads = (try? context.fetch(FetchDescriptor<ChapterRead>())) ?? []
            let placements = Dictionary(kept.map { ($0.key, IslandPlacement(x: $0.x, y: $0.y, rotation: $0.rotation, moved: true)) },
                                        uniquingKeysWith: { a, _ in a })
            let island = Island.build(chapters: reads.map { ($0.bookID, $0.chapterNumber, $0.date) }, quizzes: [], verses: [],
                                      features: [.library], placements: placements)
            // A moved Place whose new (bigger or smaller) footprint now overlaps goes back to automatic.
            for item in kept where island.conflicts.contains(item.key) { context.delete(item) }
        }
        try? context.save()
        defaults.set(-1, forKey: StorageKeys.gardenSeenChapters)
        defaults.removeObject(forKey: StorageKeys.islandProgressSeen)
        defaults.set(current, forKey: versionKey)
    }
}

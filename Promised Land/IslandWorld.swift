import SwiftUI

/// People and the island's buildings, worked out each frame. The still island (ground, Places,
/// trees) is drawn once in the cached layer; people are drawn over it. Someone standing behind a
/// building (`IslandCamera.isBehind` against its footprint's front-most corner) gets that building,
/// and everything in front of it, drawn again over them, clipped to their own rect and in the
/// island's own back-to-front order. Nothing on the island is copied anywhere else or moved
/// separately: every item is placed only from its grid point, every person from where they stand,
/// through the same camera.
enum IslandWorld {
    /// Someone to place in the order: an id, where their feet are (view points) and the rect they
    /// cover on screen.
    struct Figure: Equatable {
        let id: String
        let feet: CGPoint
        let rect: CGRect
    }

    /// The items whose drawing reaches into `visible`, in back-to-front order. A pure function of
    /// the camera: an item that stays inside the rect is never dropped and re-added.
    static func visibleItems(_ ordered: [Island.Item], layout: IslandLayout, visible: CGRect) -> [(item: Island.Item, bounds: CGRect)] {
        // A quick test on the anchor first (nothing is taller than this many tiles above its spot).
        let reach = visible.insetBy(dx: -layout.scale * 6, dy: -layout.scale * 10)
        var out: [(Island.Item, CGRect)] = []
        out.reserveCapacity(ordered.count)
        for item in ordered {
            guard reach.contains(layout.point(item.gx, item.gy)) else { continue }
            let bounds = IslandPainter.drawnBounds(of: item, layout: layout)
            if bounds.intersects(visible) || pictureRect(item, layout: layout).intersects(visible) { out.append((item, bounds)) }
        }
        return out
    }

    /// Everything an item's picture can cover (the same frame its cached picture is rendered in).
    static func pictureRect(_ item: Island.Item, layout: IslandLayout) -> CGRect {
        // Worked out about the origin and then moved to the item's spot, exactly as `drawItem` places
        // its picture (some shapes don't take a position).
        let u = layout.u
        let base = layout.point(item.gx, item.gy)
        let shape = IslandHitTester.shape(of: item, base: .zero, u: u)
        return shape.insetBy(dx: -shape.width * 0.3 - 4 * u, dy: -shape.height * 0.2 - 4 * u).offsetBy(dx: base.x, dy: base.y)
    }

    /// The items to draw again over someone, inside their rect only: if they stand behind a tall
    /// item overlapping them, that item and every item after it (in back-to-front order) that
    /// reaches into their rect; otherwise none. Drawn clipped to the person, this puts exactly the
    /// right part of the island back in front of them, in the island's own order, so nothing is
    /// pasted over its neighbours and nothing changes anywhere else on screen.
    static func itemsOver(_ f: Figure, items: [(item: Island.Item, bounds: CGRect)], layout: IslandLayout) -> [Int] {
        guard let first = items.firstIndex(where: { entry in
            entry.item.kind.isTall && entry.bounds.intersects(f.rect) && IslandCamera.isBehind(feet: f.feet, item: entry.item, layout: layout)
        }) else { return [] }
        return (first..<items.count).filter { i in
            items[i].bounds.intersects(f.rect) || pictureRect(items[i].item, layout: layout).intersects(f.rect)
        }
    }
}

/// The island's layers inside the moving part of the scene, bottom to top (their `zIndex`). The
/// sea's waves and the cached ground and Places sit below all of these; the camera buttons and
/// sheets above.
enum IslandLayer: Double, CaseIterable {
    /// Dimming while something is built.
    case dim
    /// People (you, Bible characters, villagers, travellers), smoke, and the buildings in front of
    /// anyone standing behind them.
    case people
    /// The piece being built, the selected item's bounce.
    case effects
    /// Birds: always above everything on the island, never depth-sorted.
    case birds
    /// Baskets and Collect All's flight (tappable, so on top).
    case baskets
    /// Speech bubbles.
    case bubbles

    var z: Double { rawValue }
}

/// A layer that's drawn again only when `key` changes. The world's layers are drawn in the world's own
/// coordinates and moved into view by one offset, so a pan within a step changes nothing in them:
/// with this, they aren't re-rendered then, only moved (the same as the ground).
struct KeyedLayer<Key: Equatable & Sendable, Content: View>: View, Equatable {
    nonisolated let key: Key
    @ViewBuilder let content: () -> Content

    nonisolated static func == (a: Self, b: Self) -> Bool { a.key == b.key }

    var body: some View { content() }
}

/// What the people layer shows: if none of it changed, it isn't drawn again.
nonisolated struct PeopleLayerKey: Equatable, Sendable {
    /// The pan step the world is drawn at (not the remainder, which only moves it).
    let drawPan: CGSize
    let zoom: CGFloat
    let angle: CGFloat
    /// The animation clock (holds still when nothing on the island is moving).
    let time: Double
    /// Who's drawn, in order, and what's drawn back over each of them.
    let people: [String]
    /// Where each of them stands in the world's own coordinates (to an eighth of a point): these don't
    /// change during a pan, but do the moment anyone moves, even between ticks of the clock.
    let places: [Int]
    let over: [[Int]]
    let facingLeft: Bool
    /// The avatar's look (its hash).
    let avatar: Int
    let zooming: Bool
    let size: CGSize
}

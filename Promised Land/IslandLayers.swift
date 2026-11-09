import SwiftUI

// The island's still layers (ground, Places, items) and its waves, drawn so that panning costs
// almost nothing: each layer is drawn at a pan rounded to `PanStep.size` onto a canvas a step
// bigger than the screen, and simply slid by what's left over (`.offset`). While the pan stays
// within a step, neither layer is planned or redrawn (they're `Equatable`, keyed by what they
// show), so a pan frame only moves two layers. Zooming and turning still redraw every frame.

/// Pans rounded to a step: the layers redraw only when the pan crosses into the next step.
nonisolated enum PanStep {
    /// Points. Each layer is this much bigger than the screen (half each side).
    static let size: CGFloat = 96

    static func rounded(_ pan: CGSize) -> CGSize {
        CGSize(width: (pan.width / size).rounded() * size, height: (pan.height / size).rounded() * size)
    }

    /// The pan a layer is drawn with: the rounded pan plus half a step (the canvas starts half a
    /// step above and left of the screen).
    static func drawPan(_ pan: CGSize) -> CGSize {
        let r = rounded(pan)
        return CGSize(width: r.width + size / 2, height: r.height + size / 2)
    }

    /// Where the layer sits so it lines up with the real pan.
    static func offset(_ pan: CGSize) -> CGSize {
        let r = rounded(pan)
        return CGSize(width: pan.width - r.width - size / 2, height: pan.height - r.height - size / 2)
    }

    static func canvasSize(_ size: CGSize) -> CGSize { CGSize(width: size.width + Self.size, height: size.height + Self.size) }
}

/// The island's items in drawing order (back to front), and the tall ones (which can hide
/// people), worked out only when something is added, moves, grows mid-reveal or the island
/// turns; never per frame. Order doesn't depend on zoom or pan (depth is the screen y, which
/// both only scale and shift).
@MainActor
final class IslandDepthOrder {
    private var key: Int?
    private(set) var all: [Island.Item] = []
    private(set) var tall: [Island.Item] = []
    #if DEBUG
    /// For tests: how many times the order has been worked out.
    private(set) var sorts = 0
    #endif

    func update(island: Island, layout: IslandLayout, overrides: [Int: CGFloat], hidden: Set<Int>) {
        var h = Hasher()
        h.combine(island.signature); h.combine(layout.angle); h.combine(overrides.count); h.combine(hidden)
        for (i, g) in overrides.sorted(by: { $0.key < $1.key }) { h.combine(i); h.combine(g) }
        let key = h.finalize()
        // An island without a signature (built by hand, e.g. in tests) is always sorted.
        guard island.signature == 0 || key != self.key else { return }
        self.key = key
        PerfProbe.measure("scene.sort") {
            all = island.items.indices.compactMap { i -> Island.Item? in
                guard !hidden.contains(i) else { return nil }
                guard let g = overrides[i] else { return island.items[i] }
                guard g > 0 else { return nil }
                var item = island.items[i]
                item.growth = g
                return item
            }.sorted { layout.depth($0.gx, $0.gy) < layout.depth($1.gx, $1.gy) }
            tall = all.filter(\.kind.isTall)
        }
        #if DEBUG
        sorts += 1
        #endif
    }
}

/// The still island: ground chunks, Places and items (cached pictures), the selection highlight
/// and, in edit mode, the grid. Redrawn only when what it shows changes (see `Key`).
struct IslandGroundLayer: View, Equatable {
    nonisolated struct Key: Equatable {
        let signature: Int
        let zoom: CGFloat
        let angle: CGFloat
        let pan: CGSize
        let size: CGSize
        let insets: EdgeInsets
        let selected: Int?
        let editing: Bool
        let editSelected: String?
        let overrides: [Int: CGFloat]
        let hidden: Set<Int>
        /// Bumped when a picture it was waiting for has been rendered (`IslandRenderProgress`).
        var rendered = 0
    }

    let key: Key
    let island: Island
    /// Items back to front (for drawing directly while turning or mid-reveal).
    let ordered: [Island.Item]
    let editing: IslandEditing?

    nonisolated static func == (a: Self, b: Self) -> Bool { a.key == b.key }

    var body: some View {
        let k = key
        let canvas = PanStep.canvasSize(k.size)
        let layout = IslandLayout(island: island, size: k.size, insets: k.insets, zoom: k.zoom, angle: k.angle).panned(k.pan)
        // While turning, the angle is between quarters: draw directly. Otherwise use the cached
        // ground chunks and Place pictures.
        let cached = k.angle == CGFloat(Int(k.angle)) ? PerfProbe.measure("scene.plan") {
            IslandRenderCache.shared.frame(island: island, size: k.size, insets: k.insets, zoom: k.zoom, quarter: layout.quarter,
                                           pan: k.pan, overrides: k.overrides, hidden: k.hidden, bake: !k.editing,
                                           viewport: CGRect(origin: .zero, size: canvas), deferMissing: true)
        } : nil
        Canvas { context, _ in
            PerfProbe.measure("static") {
                RenderStats.staticLayer = cached.map { $0.ground.count + $0.layers.count } ?? ordered.count
                if let cached {
                    for g in cached.ground { context.draw(Image(decorative: g.image, scale: 1), in: g.rect) }
                } else {
                    IslandPainter.drawTiles(&context, island: island, layout: layout)
                }
                if let selected = k.selected, island.items.indices.contains(selected) {
                    // The ring is on the ground: under the buildings. Close in they're drawn after it
                    // anyway; far out they're baked into the ground below it, so the ones over it are
                    // drawn again on top, inside the ring only.
                    let item = island.items[selected]
                    PlatformScene.drawHighlight(&context, item, layout: layout)
                    if cached?.baked == true {
                        var g = context
                        g.clip(to: Path(ellipseIn: PlatformScene.highlightRect(item, layout: layout)))
                        for over in PlatformScene.itemsOverRing(item, ordered: ordered, layout: layout) {
                            IslandRenderCache.shared.drawItem(&g, over, layout: layout)
                        }
                    }
                }
                if let editing {
                    PlatformScene.drawEditGrid(&context, island: island, layout: layout, editing: editing)
                    PlatformScene.drawExtraRings(&context, island: island, layout: layout, editing: editing)
                }
                // Only what's on screen is drawn: anything whose picture reaches into the canvas
                // (not just its anchor, which left tall things at the edges drawn late).
                let visible = CGRect(origin: .zero, size: canvas)
                if let cached {
                    for layer in cached.layers {
                        switch layer {
                        case .picture(let image, let rect): context.draw(Image(decorative: image, scale: 1), in: rect)
                        case .item(let item):
                            if IslandWorld.pictureRect(item, layout: layout).intersects(visible) { IslandPainter.drawItem(&context, item, layout: layout) }
                        }
                    }
                } else {
                    for item in ordered where IslandWorld.pictureRect(item, layout: layout).intersects(visible) {
                        IslandPainter.drawItem(&context, item, layout: layout)
                    }
                }
                #if DEBUG
                if PlatformScene.showHitBoxes { PlatformScene.drawHitBoxes(&context, island: island, layout: layout) }
                #endif
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .allowsHitTesting(false)
    }
}

/// The sea (12 frames a second): wave marks over the whole visible sea, laid out on the island's
/// grid, and the surf along its coast. Drawn at a rounded pan like the ground, but always at the
/// camera itself (never the scaled still drawing), so it covers the whole screen while zooming too.
struct IslandWavesLayer: View, Equatable {
    nonisolated struct Key: Equatable {
        let signature: Int
        let zoom: CGFloat
        let angle: CGFloat
        let pan: CGSize
        let size: CGSize
        let insets: EdgeInsets
        let reduceMotion: Bool
        /// Covered by a full-screen view: the waves hold still until it closes.
        let paused: Bool
    }

    let key: Key
    let island: Island

    nonisolated static func == (a: Self, b: Self) -> Bool { a.key == b.key }

    var body: some View {
        let k = key
        let canvas = PanStep.canvasSize(k.size)
        let layout = IslandLayout(island: island, size: k.size, insets: k.insets, zoom: k.zoom, angle: k.angle).panned(k.pan)
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: k.reduceMotion || k.paused)) { context in
            Canvas { c, _ in
                PerfProbe.measure("waves") {
                    // The whole sea, out to every edge of the screen at any zoom and turn.
                    IslandPainter.drawOpenSea(&c, island: island, layout: layout,
                                              time: k.reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate,
                                              visible: CGRect(origin: .zero, size: canvas).insetBy(dx: -20, dy: -20))
                    IslandPainter.drawWaves(&c, island: island, layout: layout,
                                            time: k.reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate,
                                            visible: CGRect(origin: .zero, size: canvas).insetBy(dx: -20, dy: -20))
                }
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .allowsHitTesting(false)
    }
}

/// A picture of the island just before a quarter turn: the old quarter's cached ground and Place
/// pictures, drawn where they were.
struct TurnSnapshot {
    let id: Int
    let frame: IslandRenderCache.Frame
    /// +1 turning right, -1 left.
    let direction: Int
}

/// Draws a `TurnSnapshot` once; the turn animates only its opacity and rotation.
struct TurnSnapshotView: View, Equatable {
    let snapshot: TurnSnapshot

    nonisolated static func == (a: Self, b: Self) -> Bool { a.snapshot.id == b.snapshot.id }

    var body: some View {
        Canvas { c, _ in
            for g in snapshot.frame.ground { c.draw(Image(decorative: g.image, scale: 1), in: g.rect) }
            for layer in snapshot.frame.layers {
                // Places are pictures; a few loose things (trees, extras) aren't, and are left out
                // of this 0.3 s picture rather than drawn.
                if case .picture(let image, let rect) = layer { c.draw(Image(decorative: image, scale: 1), in: rect) }
            }
        }
    }
}

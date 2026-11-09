import SwiftUI

/// Keeps the island smooth with a fully built Bible. Drawing every tile and every code-drawn
/// shape on every frame is far too slow, so:
/// - the ground is rendered once into 512-point chunks (per zoom bucket and turn) and reused;
/// - each Place (all its pieces, flowers, banner and lantern) is rendered once into one image,
///   keyed by what's in it (not where it is: the isometric projection is affine, so the same
///   picture works wherever the Place sits, even mid-drag in edit mode);
/// - zoom is bucketed, and pictures are scaled a little between buckets;
/// - only what's on screen is rendered or drawn.
/// Images live in an `NSCache` with a memory limit, so old ones are dropped under pressure.
@MainActor
final class IslandRenderCache {
    static let shared = IslandRenderCache()

    private let images = NSCache<NSString, ImageBox>()
    private var placeKeys: (signature: Int, keys: [String: Int]) = (0, [:])
    /// `groundBounds` per ground key (it walks every tile, so never per frame).
    private var groundExtents: [String: CGRect] = [:]
    /// While warming ahead: how many more pictures may be rendered in this call (nil: no limit),
    /// and how many were left for later.
    private var renderBudget: Int?
    private var skipped = 0
    #if DEBUG
    /// For tests: pictures rendered so far.
    private(set) var renders = 0
    #endif

    /// 160 MB evicted pictures a close-in quarter turn needed (NSCache may evict well before its
    /// limit), so turning there redrew them on the spot. At 512 MB nothing was evicted, and the whole
    /// app measured about 150 MB with all four quarters warm. The cache also empties itself under
    /// memory pressure.
    private init() { images.totalCostLimit = 512 * 1024 * 1024 }

    final class ImageBox {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }

    /// Zoom buckets: pictures are rendered at these zooms and scaled in between (×1.25 apart,
    /// up to the closest zoom on the biggest island).
    static let buckets: [CGFloat] = [1, 1.25, 1.6, 2, 2.5, 3.2, 4, 5, 6.4, 8, 10, 12.5, 16, 20, 25, 32, 40, 50, 64, 80]

    static func bucket(for zoom: CGFloat) -> CGFloat {
        buckets.first { $0 >= zoom - 0.001 } ?? buckets.last!
    }

    private var renderScale: CGFloat { min(2, UITraitCollection.current.displayScale) }

    // MARK: Frame

    /// What the static layer draws this frame: cached pictures, and items drawn directly.
    struct Frame {
        var ground: [(image: CGImage, rect: CGRect)] = []
        /// In back-to-front order: a cached Place picture, or an item drawn as usual.
        var layers: [Layer] = []

        enum Layer {
            case picture(CGImage, CGRect)
            case item(Island.Item)
        }
    }

    /// Plans the static layer for the current camera. `base` is the camera at `zoom` without
    /// the pan; `overrides` are items held at another growth (during a reveal), drawn directly.
    /// `viewport` is the area drawn into (defaults to the view, with a small margin).
    func frame(island: Island, size: CGSize, insets: EdgeInsets, zoom: CGFloat, quarter: Int, pan: CGSize,
               overrides: [Int: CGFloat], hidden: Set<Int>, bake: Bool = true, viewport: CGRect? = nil) -> Frame? {
        renderBudget = nil
        return plan(island: island, size: size, insets: insets, zoom: zoom, quarter: quarter, pan: pan,
                    overrides: overrides, hidden: hidden, bake: bake, viewport: viewport)
    }

    /// The land alone (tiles, roads, plots), which is all the ground drawing depends on.
    func groundSignature(_ island: Island) -> Int {
        if let known = groundSignatures[island.signature], island.signature != 0 { return known }
        var h = Hasher()
        h.combine(island.tiles.count)
        for t in island.tiles { h.combine(t.x); h.combine(t.y) }
        for road in island.roads { h.combine(road.count); for t in road { h.combine(t.x); h.combine(t.y) } }
        for p in island.allPlots { h.combine(p.bookID); h.combine(p.x); h.combine(p.y); h.combine(p.size); h.combine(p.rotation); h.combine(p.bay) }
        let sig = h.finalize()
        if groundSignatures.count > 32 { groundSignatures.removeAll() }
        groundSignatures[island.signature] = sig
        return sig
    }

    private var groundSignatures: [Int: Int] = [:]

    /// Renders ahead what `frame` would need for this camera (e.g. the next quarter turn), at most
    /// one picture per call so it never holds up a frame. Returns true when everything is ready.
    @discardableResult
    func prewarm(island: Island, size: CGSize, insets: EdgeInsets, zoom: CGFloat, quarter: Int, pan: CGSize, bake: Bool,
                 viewport: CGRect? = nil) -> Bool {
        renderBudget = 1
        skipped = 0
        defer { renderBudget = nil }
        _ = plan(island: island, size: size, insets: insets, zoom: zoom, quarter: quarter, pan: pan,
                 overrides: [:], hidden: [], bake: bake, viewport: viewport)
        return skipped == 0 && renderBudget == 1
    }

    private func plan(island: Island, size: CGSize, insets: EdgeInsets, zoom: CGFloat, quarter: Int, pan: CGSize,
                      overrides: [Int: CGFloat], hidden: Set<Int>, bake: Bool, viewport: CGRect?) -> Frame? {
        guard island.signature != 0, size.width > 0 else { return nil }
        let zb = Self.bucket(for: zoom)
        let lb = IslandLayout(island: island, size: size, insets: insets, zoom: zb, angle: CGFloat(quarter))
        let centre = CGPoint(x: insets.leading + (size.width - insets.leading - insets.trailing) / 2,
                             y: insets.top + (size.height - insets.top - insets.bottom) / 2)
        // The bucket layout may be clamped to the island's zoom limit: scale from the zoom it really has.
        let k = zoom / lb.zoom
        func screen(_ r: CGRect) -> CGRect {
            CGRect(x: centre.x + (r.minX - centre.x) * k + pan.width, y: centre.y + (r.minY - centre.y) * k + pan.height,
                   width: r.width * k, height: r.height * k)
        }
        let view = (viewport ?? CGRect(origin: .zero, size: size)).insetBy(dx: -20, dy: -20)
        var frame = Frame()

        // Ground chunks.
        // Far out (and not mid-reveal), everything that stands still is baked into the ground
        // chunks too: a handful of images instead of a picture per Place and hundreds of items.
        let baked = bake && lb.u < IslandLOD.middleShow && overrides.isEmpty && hidden.isEmpty
        // Plain ground depends only on the land: a building growing never re-bakes it. Far out,
        // the still things are baked in too, so those chunks follow the whole island.
        let landKey = baked ? "b\(island.signature)" : "l\(groundSignature(island))"
        let groundKey = "\(landKey)|\(Int(lb.scale * 100))|\(quarter)|\(Int(size.width))x\(Int(size.height))"
        // The ground's extent only changes with the island, zoom bucket, turn and size: worked out once.
        let bounds: CGRect
        if let known = groundExtents[groundKey] { bounds = known } else {
            bounds = groundBounds(island, layout: lb)
            if groundExtents.count > 64 { groundExtents.removeAll() }
            groundExtents[groundKey] = bounds
        }
        let chunk: CGFloat = 512
        let x0 = Int(floor(bounds.minX / chunk)), x1 = Int(floor(bounds.maxX / chunk))
        let y0 = Int(floor(bounds.minY / chunk)), y1 = Int(floor(bounds.maxY / chunk))
        for cy in y0...y1 {
            for cx in x0...x1 {
                let rect = CGRect(x: CGFloat(cx) * chunk, y: CGFloat(cy) * chunk, width: chunk, height: chunk)
                let dest = screen(rect)
                guard dest.intersects(view) else { continue }
                let key = "\(groundKey)|\(cx),\(cy)" as NSString
                let image = images.object(forKey: key)?.image ?? render(key: key, size: rect.size) { c in
                    let l = lb.panned(CGSize(width: -rect.minX, height: -rect.minY))
                    let local = CGRect(origin: .zero, size: rect.size)
                    IslandPainter.drawTiles(&c, island: island, layout: l, visible: local)
                    if baked {
                        // Every item whose drawing reaches into this chunk, back to front.
                        let margin = l.u * 240
                        for item in island.items.sorted(by: { l.depth($0.gx, $0.gy) < l.depth($1.gx, $1.gy) }) {
                            let p = l.point(item.gx, item.gy)
                            guard local.insetBy(dx: -margin, dy: -margin).contains(p) else { continue }
                            IslandPainter.drawItem(&c, item, layout: l)
                        }
                    }
                }
                if let image { frame.ground.append((image, dest)) }
            }
        }
        if baked { return frame }

        // Places as pictures; everything else (and anything mid-reveal) item by item.
        let keys = placeContentKeys(island)
        var byPlot: [String: [Int]] = [:]
        var loose: [Int] = []
        for (i, item) in island.items.enumerated() where !hidden.contains(i) {
            if let key = item.plotKey, keys[key] != nil { byPlot[key, default: []].append(i) } else { loose.append(i) }
        }
        var layers: [(depth: CGFloat, layer: Frame.Layer)] = []
        for plot in island.allPlots {
            guard let indices = byPlot[plot.bookID], let content = keys[plot.bookID] else { continue }
            let rect = placeRect(plot, layout: lb)
            let dest = screen(rect)
            let depth = lb.point(plot.centre.x, plot.centre.y).y
            if indices.contains(where: { overrides[$0] != nil }) {
                // Mid-reveal: drawn item by item, at the growth the reveal says.
                for i in indices {
                    var item = island.items[i]
                    if let g = overrides[i] { guard g > 0 else { continue }; item.growth = g }
                    layers.append((lb.point(item.gx, item.gy).y + 0.001, .item(item)))
                }
                continue
            }
            guard dest.intersects(view) else { continue }
            // Keyed by what's in it, the layout's scale and the turn (not where it is).
            let key = "p\(content)|\(Int(lb.scale * 100))|\(quarter)" as NSString
            let image = images.object(forKey: key)?.image ?? render(key: key, size: rect.size) { c in
                let l = lb.panned(CGSize(width: -rect.minX, height: -rect.minY))
                for i in indices.sorted(by: { lb.depth(island.items[$0].gx, island.items[$0].gy) < lb.depth(island.items[$1].gx, island.items[$1].gy) }) {
                    IslandPainter.drawItem(&c, island.items[i], layout: l)
                }
            }
            if let image { layers.append((depth, .picture(image, dest))) }
        }
        for i in loose {
            var item = island.items[i]
            if let g = overrides[i] { guard g > 0 else { continue }; item.growth = g }
            layers.append((lb.point(item.gx, item.gy).y, .item(item)))
        }
        frame.layers = layers.sorted { $0.depth < $1.depth }.map(\.layer)
        return frame
    }

    // MARK: Single items

    /// Draws one item from its cached picture (rendered once per look, zoom bucket and turn),
    /// positioned only from its grid point: used to put buildings back in front of someone standing
    /// behind them (clipped to that person), so they don't cost a full redraw every frame.
    func drawItem(_ c: inout GraphicsContext, _ item: Island.Item, layout: IslandLayout) {
        guard let p = itemPicture(item, layout: layout) else { IslandPainter.drawItem(&c, item, layout: layout); return }
        let k = layout.u / p.ub
        let base = layout.point(item.gx, item.gy)
        c.draw(Image(decorative: p.image, scale: 1),
               in: CGRect(x: base.x + p.frame.minX * k, y: base.y + p.frame.minY * k, width: p.frame.width * k, height: p.frame.height * k))
    }

    /// An item's picture at this camera's size bucket and turn (rendered if it isn't cached), with
    /// its frame relative to the item's grid point, in bucket units.
    private func itemPicture(_ item: Island.Item, layout: IslandLayout) -> (image: CGImage, frame: CGRect, ub: CGFloat)? {
        let ub = Self.sizeBucket(layout.u)
        let shape = IslandHitTester.shape(of: item, base: .zero, u: ub)
        let frame = shape.insetBy(dx: -shape.width * 0.3 - 4 * ub, dy: -shape.height * 0.2 - 4 * ub).integral
        guard frame.width > 0, frame.height > 0, frame.width * frame.height < 4_000_000 else { return nil }
        let key = itemKey(item, layout: layout)
        let quarter = layout.quarter, mirrored = layout.mirrored
        guard let image = images.object(forKey: key)?.image ?? render(key: key, size: frame.size, draw: { g in
            g.translateBy(x: -frame.minX, y: -frame.minY)
            IslandPainter.drawAtOrigin(&g, item, u: ub, quarter: quarter, layoutMirrored: mirrored)
        }) else { return nil }
        return (image, frame, ub)
    }

    /// Size units are bucketed ×1.25 apart; pictures are scaled a little in between.
    static func sizeBucket(_ u: CGFloat) -> CGFloat { CGFloat(pow(1.25, ceil(log(Double(max(0.05, u))) / log(1.25)))) }

    /// Is this item's picture at this camera already rendered?
    func hasPicture(_ item: Island.Item, layout: IslandLayout) -> Bool {
        images.object(forKey: itemKey(item, layout: layout)) != nil
    }

    private func itemKey(_ item: Island.Item, layout: IslandLayout) -> NSString {
        let ub = Self.sizeBucket(layout.u)
        var h = Hasher()
        h.combine(item.kind); h.combine(item.growth); h.combine(item.level); h.combine(item.turned); h.combine(item.facing)
        h.combine(item.seed); h.combine(item.progress); h.combine(item.total); h.combine(item.libraryTouches); h.combine(item.span)
        h.combine(item.cap); h.combine(item.source.bookID)
        return "i\(h.finalize())|\(Int(ub * 1000))|\(layout.quarter)" as NSString
    }

    /// Any small code-drawn picture, rendered once per `key` and reused (e.g. produce baskets).
    func picture(_ key: String, size: CGSize, draw: @escaping (inout GraphicsContext) -> Void) -> CGImage? {
        let k = key as NSString
        return images.object(forKey: k)?.image ?? render(key: k, size: size, draw: draw)
    }

    /// The ground's extent in a layout's points (with room for the shore and earth sides).
    private func groundBounds(_ island: Island, layout: IslandLayout) -> CGRect {
        var minX = CGFloat.infinity, minY = CGFloat.infinity, maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        for t in island.tiles {
            for (dx, dy) in [(0, 0), (1, 0), (0, 1), (1, 1)] {
                let p = layout.point(CGFloat(t.x + dx), CGFloat(t.y + dy))
                minX = min(minX, p.x); maxX = max(maxX, p.x); minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
        }
        let m = layout.u * 20
        return CGRect(x: minX - m, y: minY - m, width: maxX - minX + 2 * m, height: maxY - minY + 2 * m + layout.depth)
    }

    /// A Place's picture frame in a layout: its footprint, plus headroom for tall things.
    private func placeRect(_ plot: Island.Plot, layout: IslandLayout) -> CGRect {
        let corners = [(plot.x - 1, plot.y - 1), (plot.x + plot.size + 1, plot.y - 1), (plot.x - 1, plot.y + plot.size + 1),
                       (plot.x + plot.size + 1, plot.y + plot.size + 1)].map { layout.point(CGFloat($0.0), CGFloat($0.1)) }
        let xs = corners.map(\.x), ys = corners.map(\.y)
        // The Library stands much taller than any Place.
        let head = layout.u * (plot.bookID == IslandPlacement.libraryKey ? 250 : 90)
        return CGRect(x: xs.min()!, y: ys.min()! - head, width: ceil(xs.max()! - xs.min()!), height: ceil(ys.max()! - ys.min()! + head))
    }

    /// A key for each Place's contents (relative to its own corner), so moving it reuses its picture.
    private func placeContentKeys(_ island: Island) -> [String: Int] {
        if placeKeys.signature == island.signature { return placeKeys.keys }
        var hashers: [String: Hasher] = [:]
        let plots = Dictionary(island.allPlots.map { ($0.bookID, $0) }, uniquingKeysWith: { a, _ in a })
        for item in island.items {
            guard let key = item.plotKey, let plot = plots[key] else { continue }
            var h = hashers[key] ?? { var h = Hasher(); h.combine(key); h.combine(plot.size); h.combine(plot.rotation); h.combine(plot.bay); return h }()
            h.combine(item.kind)
            h.combine(Int(((item.gx - CGFloat(plot.x)) * 1000).rounded()))
            h.combine(Int(((item.gy - CGFloat(plot.y)) * 1000).rounded()))
            h.combine(item.growth); h.combine(item.level); h.combine(item.turned); h.combine(item.facing); h.combine(item.seed)
            h.combine(item.progress); h.combine(item.total); h.combine(item.libraryTouches); h.combine(item.span)
            hashers[key] = h
        }
        let keys = hashers.mapValues { $0.finalize() }
        placeKeys = (island.signature, keys)
        return keys
    }

    private func render(key: NSString, size: CGSize, draw: @escaping (inout GraphicsContext) -> Void) -> CGImage? {
        if let budget = renderBudget {
            guard budget > 0 else { skipped += 1; return nil }
            renderBudget = budget - 1
        }
        #if DEBUG
        renders += 1
        #endif
        let renderer = ImageRenderer(content: Canvas { c, _ in draw(&c) }.frame(width: size.width, height: size.height))
        renderer.scale = renderScale
        guard let image = renderer.cgImage else { return nil }
        images.setObject(ImageBox(image), forKey: key, cost: image.bytesPerRow * image.height)
        return image
    }
}

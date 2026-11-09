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
        /// Ground pictures and where they go; a stand-in from another zoom is clipped to just the gap
        /// it fills (`clip`), so no part of the island is ever drawn twice.
        var ground: [(image: CGImage, rect: CGRect, clip: CGRect?)] = []
        /// Far out, where a stand-in has ground but no buildings: the buildings (`layers`) are drawn
        /// only inside these, so none is drawn on top of its own baked copy next door.
        var layerClip: [CGRect]?
        /// Far out: the island's still things are baked into the ground chunks.
        var baked = false
        /// Where the ground drawn includes the buildings (chunks from a far-out zoom).
        var bakedGround: [CGRect] = []
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
    /// - Parameter deferMissing: pictures not yet rendered at this zoom are drawn from the nearest
    ///   zoom that has them and rendered in the background (for the live island, so a zoom never
    ///   waits on rendering and never leaves land out). Otherwise they're rendered now.
    func frame(island: Island, size: CGSize, insets: EdgeInsets, zoom: CGFloat, quarter: Int, pan: CGSize,
               overrides: [Int: CGFloat], hidden: Set<Int>, bake: Bool = true, viewport: CGRect? = nil,
               deferMissing: Bool = false) -> Frame? {
        renderBudget = nil
        return plan(island: island, size: size, insets: insets, zoom: zoom, quarter: quarter, pan: pan,
                    overrides: overrides, hidden: hidden, bake: bake, viewport: viewport, deferMissing: deferMissing)
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
                 viewport: CGRect? = nil, groundOnly: Bool = false) -> Bool {
        renderBudget = 1
        skipped = 0
        defer { renderBudget = nil }
        _ = plan(island: island, size: size, insets: insets, zoom: zoom, quarter: quarter, pan: pan,
                 overrides: [:], hidden: [], bake: bake, viewport: viewport, groundOnly: groundOnly)
        return skipped == 0 && renderBudget == 1
    }

    /// A zoom bucket's geometry: its layout, how it maps to the camera, and its ground chunks' key.
    private struct Bucket {
        let lb: IslandLayout
        /// Camera zoom ÷ the bucket layout's zoom.
        let k: CGFloat
        let baked: Bool
        let groundKey: String
        let bounds: CGRect
    }

    private func bucket(_ zb: CGFloat, island: Island, size: CGSize, insets: EdgeInsets, zoom: CGFloat, quarter: Int,
                        bake: Bool, overrides: [Int: CGFloat], hidden: Set<Int>) -> Bucket {
        let lb = IslandLayout(island: island, size: size, insets: insets, zoom: zb, angle: CGFloat(quarter))
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
        // The bucket layout may be clamped to the island's zoom limit: scale from the zoom it really has.
        return Bucket(lb: lb, k: zoom / lb.zoom, baked: baked, groundKey: groundKey, bounds: bounds)
    }

    private static let chunk: CGFloat = 512

    /// Draws one ground chunk of a bucket.
    private func chunkDrawing(island: Island, bucket b: Bucket, rect: CGRect) -> (inout GraphicsContext) -> Void {
        let lb = b.lb, baked = b.baked
        return { c in
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
    }

    /// The same chunk as `chunkDrawing`, in slices to render one per frame: the ground, then the baked
    /// buildings and trees a dozen at a time (back to front). Far out a chunk holds hundreds of them and
    /// took 300–600 ms in one go; a slice is a few milliseconds.
    private func chunkSteps(island: Island, bucket b: Bucket, rect: CGRect) -> [(inout GraphicsContext) -> Void] {
        let lb = b.lb
        let l = lb.panned(CGSize(width: -rect.minX, height: -rect.minY))
        let local = CGRect(origin: .zero, size: rect.size)
        var steps: [(inout GraphicsContext) -> Void] = [{ c in IslandPainter.drawTiles(&c, island: island, layout: l, visible: local) }]
        guard b.baked else { return steps }
        let margin = l.u * 240
        let items = island.items.sorted(by: { l.depth($0.gx, $0.gy) < l.depth($1.gx, $1.gy) })
            .filter { local.insetBy(dx: -margin, dy: -margin).contains(l.point($0.gx, $0.gy)) }
        for start in stride(from: 0, to: items.count, by: Self.itemsPerSlice) {
            let batch = Array(items[start..<min(items.count, start + Self.itemsPerSlice)])
            steps.append { c in for item in batch { IslandPainter.drawItem(&c, item, layout: l) } }
        }
        return steps
    }

    static let itemsPerSlice = 12

    /// The other zoom buckets, nearest first (for drawing something that's already cached while a
    /// picture for this zoom is still being rendered).
    private static func neighbours(of zb: CGFloat) -> [CGFloat] {
        let near = buckets.filter { $0 != zb }.sorted { abs(log($0 / zb)) < abs(log($1 / zb)) }.prefix(6).map { $0 }
        // The whole-island overview (zoom 1, made when the island first appears) is always the last resort.
        return near.contains(overviewZoom) || zb == overviewZoom ? near : near + [overviewZoom]
    }

    /// The zoom the whole-island overview is drawn at.
    static let overviewZoom: CGFloat = 1

    private func plan(island: Island, size: CGSize, insets: EdgeInsets, zoom: CGFloat, quarter: Int, pan: CGSize,
                      overrides: [Int: CGFloat], hidden: Set<Int>, bake: Bool, viewport: CGRect?, deferMissing: Bool = false,
                      groundOnly: Bool = false) -> Frame? {
        guard island.signature != 0, size.width > 0 else { return nil }
        let zb = Self.bucket(for: zoom)
        let b = bucket(zb, island: island, size: size, insets: insets, zoom: zoom, quarter: quarter, bake: bake, overrides: overrides, hidden: hidden)
        let lb = b.lb
        let centre = CGPoint(x: insets.leading + (size.width - insets.leading - insets.trailing) / 2,
                             y: insets.top + (size.height - insets.top - insets.bottom) / 2)
        func screen(_ r: CGRect, _ k: CGFloat) -> CGRect {
            CGRect(x: centre.x + (r.minX - centre.x) * k + pan.width, y: centre.y + (r.minY - centre.y) * k + pan.height,
                   width: r.width * k, height: r.height * k)
        }
        /// A screen rect back in a bucket's own coordinates.
        func local(_ r: CGRect, _ k: CGFloat) -> CGRect {
            CGRect(x: centre.x + (r.minX - pan.width - centre.x) / k, y: centre.y + (r.minY - pan.height - centre.y) / k,
                   width: r.width / k, height: r.height / k)
        }
        let view = (viewport ?? CGRect(origin: .zero, size: size)).insetBy(dx: -20, dy: -20)
        var frame = Frame()
        frame.baked = b.baked
        var queued: [Pending] = []
        /// Every picture this frame draws (held for the next frame, see `held`).
        var used: [NSString: CGImage] = [:]
        /// Far out, where the ground is drawn from a closer zoom (without its buildings) for now.
        var plainRegions: [CGRect] = []

        // Ground chunks: every one in view, worked out from the camera now.
        let chunk = Self.chunk
        var missing: [(dest: CGRect, key: NSString, size: CGSize, scale: CGFloat, draw: (inout GraphicsContext) -> Void,
                       steps: () -> [(inout GraphicsContext) -> Void])] = []
        let x0 = Int(floor(b.bounds.minX / chunk)), x1 = Int(floor(b.bounds.maxX / chunk))
        let y0 = Int(floor(b.bounds.minY / chunk)), y1 = Int(floor(b.bounds.maxY / chunk))
        for cy in y0...y1 {
            for cx in x0...x1 {
                let rect = CGRect(x: CGFloat(cx) * chunk, y: CGFloat(cy) * chunk, width: chunk, height: chunk)
                let dest = screen(rect, b.k)
                guard dest.intersects(view) else { continue }
                let key = "\(b.groundKey)|\(cx),\(cy)" as NSString
                if let image = picture(key, using: &used) {
                    frame.ground.append((image, dest, nil))
                    if b.baked { frame.bakedGround.append(dest) }
                } else if deferMissing {
                    missing.append((dest, key, rect.size, chunkScale(b), chunkDrawing(island: island, bucket: b, rect: rect),
                                    { self.chunkSteps(island: island, bucket: b, rect: rect) }))
                } else if renderBudget != nil, b.baked {
                    // Warming ahead: a far-out chunk is far too big to render in one frame; it's made
                    // in slices in the background instead (and this warm-up isn't done until it is).
                    skipped += 1
                    enqueue(Pending(key: key, size: rect.size, scale: chunkScale(b), steps: chunkSteps(island: island, bucket: b, rect: rect)))
                } else if let image = render(key: key, size: rect.size, scale: chunkScale(b), draw: chunkDrawing(island: island, bucket: b, rect: rect)) {
                    used[key] = image
                    frame.ground.append((image, dest, nil))
                    if b.baked { frame.bakedGround.append(dest) }
                }
            }
        }
        if !missing.isEmpty {
            // Not rendered at this zoom yet: draw the same ground from the nearest zoom that has it
            // (scaled into place) underneath, and render this zoom's in the background. Land on
            // screen is never left out.
            var under: [(image: CGImage, rect: CGRect, clip: CGRect?)] = []
            var open = missing
            // Only a stand-in drawn the same way: close in the ground alone (the buildings are drawn
            // separately, sharp), so never ground with buildings baked in, which would leave a blurry
            // copy behind each sharp one. Far out, ground with buildings first; failing that, the
            // ground alone, with its buildings drawn on it below.
            let candidates: [Bucket] = (b.baked ? [true, false] : [false]).flatMap { baked in
                // The ground-alone version of this very zoom counts too (far out, e.g. the overview's own zoom).
                ((b.baked && !baked ? [zb] : []) + Self.neighbours(of: zb)).map { zb2 in
                    bucket(zb2, island: island, size: size, insets: insets, zoom: zoom, quarter: quarter, bake: baked ? bake : false,
                           overrides: overrides, hidden: hidden)
                }.filter { $0.baked == baked }
            }
            for b2 in candidates where !open.isEmpty {
                open = open.filter { m in
                    let r = local(m.dest, b2.k)
                    let cx0 = Int(floor(r.minX / chunk)), cx1 = Int(floor((r.maxX - 0.001) / chunk))
                    let cy0 = Int(floor(r.minY / chunk)), cy1 = Int(floor((r.maxY - 0.001) / chunk))
                    var found: [(image: CGImage, rect: CGRect, clip: CGRect?)] = []
                    for cy in cy0...cy1 {
                        for cx in cx0...cx1 {
                            let rect = CGRect(x: CGFloat(cx) * chunk, y: CGFloat(cy) * chunk, width: chunk, height: chunk)
                            // Outside the island's ground there's nothing to draw.
                            guard rect.intersects(b2.bounds) else { continue }
                            guard let image = picture("\(b2.groundKey)|\(cx),\(cy)" as NSString, using: &used) else { return true }
                            // Only inside the gap it fills: the chunks around it are this zoom's own.
                            found.append((image, screen(rect, b2.k), m.dest))
                        }
                    }
                    if b2.baked { frame.bakedGround.append(contentsOf: found.map { $0.rect.intersection(m.dest) }) }
                    under.append(contentsOf: found)
                    // Far out the buildings are part of the ground; a closer zoom's ground has none,
                    // so they're drawn on it separately (below) until this zoom's chunk is ready.
                    if b.baked && !b2.baked { plainRegions.append(m.dest) }
                    return false
                }
            }
            frame.ground = under + frame.ground
            for m in missing {
                if open.contains(where: { $0.key == m.key }) {
                    // Nothing cached at any zoom: draw it now.
                    if let image = render(key: m.key, size: m.size, scale: m.scale, draw: m.draw) {
                        used[m.key] = image
                        frame.ground.append((image, m.dest, nil))
                        if b.baked { frame.bakedGround.append(m.dest) }
                    }
                } else {
                    queued.append(Pending(key: m.key, size: m.size, scale: m.scale, steps: m.steps()))
                }
            }
        }
        if groundOnly || (b.baked && plainRegions.isEmpty) { finish(queued, deferMissing); hold(used, deferMissing); return frame }
        // Far out with some ground standing in from a closer zoom: only the buildings there are
        // drawn separately, and only from pictures already made (the baked chunk will come), and
        // only inside those stand-ins (`layerClip`), never over the baked chunks next to them.
        func wanted(_ r: CGRect) -> Bool { !b.baked || plainRegions.contains { $0.intersects(r) } }
        if b.baked { frame.layerClip = plainRegions }

        // Places as pictures; everything else (and anything mid-reveal) item by item.
        let keys = placeContentKeys(island)
        var byPlot: [String: [Int]] = [:]
        var loose: [Int] = []
        for (i, item) in island.items.enumerated() where !hidden.contains(i) {
            if let key = item.plotKey, keys[key] != nil { byPlot[key, default: []].append(i) } else { loose.append(i) }
        }
        var layers: [(depth: CGFloat, layer: Frame.Layer)] = []
        var others: [Bucket]?
        for plot in island.allPlots {
            guard let indices = byPlot[plot.bookID], let content = keys[plot.bookID] else { continue }
            let rect = placeRect(plot, layout: lb)
            let dest = screen(rect, b.k)
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
            guard dest.intersects(view), wanted(dest) else { continue }
            // Keyed by what's in it, the layout's scale and the turn (not where it is).
            let key = "p\(content)|\(Int(lb.scale * 100))|\(quarter)" as NSString
            let draw: (inout GraphicsContext) -> Void = { c in
                let l = lb.panned(CGSize(width: -rect.minX, height: -rect.minY))
                for i in indices.sorted(by: { lb.depth(island.items[$0].gx, island.items[$0].gy) < lb.depth(island.items[$1].gx, island.items[$1].gy) }) {
                    IslandPainter.drawItem(&c, island.items[i], layout: l)
                }
            }
            if let image = picture(key, using: &used) {
                layers.append((depth, .picture(image, dest)))
                continue
            }
            if deferMissing {
                // Not rendered at this zoom yet: the same Place's picture from the nearest zoom that has it.
                if others == nil {
                    others = Self.neighbours(of: zb).map {
                        bucket($0, island: island, size: size, insets: insets, zoom: zoom, quarter: quarter, bake: bake, overrides: overrides, hidden: hidden)
                    }
                }
                if let (image, b2) = others!.lazy.compactMap({ b2 -> (CGImage, Bucket)? in
                    self.picture("p\(content)|\(Int(b2.lb.scale * 100))|\(quarter)" as NSString, using: &used).map { ($0, b2) }
                }).first {
                    layers.append((depth, .picture(image, screen(placeRect(plot, layout: b2.lb), b2.k))))
                    if !b.baked { queued.append(Pending(key: key, size: rect.size, scale: renderScale, steps: [draw])) }
                    continue
                }
                if b.baked || interacting {
                    // No picture of it at any zoom yet: its pieces are drawn directly meanwhile (never a
                    // picture rendered mid-gesture); it gets its picture once the camera stops.
                    if !b.baked { queued.append(Pending(key: key, size: rect.size, scale: renderScale, steps: [draw])) }
                    for i in indices { layers.append((lb.point(island.items[i].gx, island.items[i].gy).y, .item(island.items[i]))) }
                    continue
                }
            }
            if let image = render(key: key, size: rect.size, draw: draw) {
                used[key] = image
                layers.append((depth, .picture(image, dest)))
            }
        }
        for i in loose {
            var item = island.items[i]
            if b.baked {
                let at = screen(CGRect(origin: lb.point(item.gx, item.gy), size: .zero), b.k)
                guard wanted(at.insetBy(dx: -30, dy: -60)) else { continue }
            }
            if let g = overrides[i] { guard g > 0 else { continue }; item.growth = g }
            layers.append((lb.point(item.gx, item.gy).y, .item(item)))
        }
        frame.layers = layers.sorted { $0.depth < $1.depth }.map(\.layer)
        finish(queued, deferMissing)
        hold(used, deferMissing)
        return frame
    }

    // MARK: What's on screen

    /// The pictures the live island drew in its last frame, held outside the cache. The cache can be
    /// emptied by the system at any moment under memory pressure; without this, the next frame of a
    /// pan would find what was on screen gone and show stand-ins from another zoom (a wrong, blurrier
    /// picture) until the pan stopped. What's on screen can never vanish now.
    private var held: [NSString: CGImage] = [:]

    /// A picture by key: held (on screen) first, then the cache. Noted in `used`.
    private func picture(_ key: NSString, using used: inout [NSString: CGImage]) -> CGImage? {
        guard let image = held[key] ?? images.object(forKey: key)?.image else { return nil }
        used[key] = image
        return image
    }

    private func hold(_ used: [NSString: CGImage], _ live: Bool) {
        guard live else { return }
        held = used
    }

    /// For tests: what the system does under memory pressure (the cache is emptied; what's on
    /// screen is held).
    func simulateMemoryWarning() { images.removeAllObjects() }

    // MARK: Rendering in the background

    /// A picture this zoom still needs (drawn meanwhile from another zoom).
    private struct Pending {
        let key: NSString
        let size: CGSize
        let scale: CGFloat
        /// Rendered one per frame, each over the last.
        let steps: [(inout GraphicsContext) -> Void]
    }

    /// A picture being made in slices: what's done so far, and how many slices that is.
    private var partial: [NSString: (image: CGImage, done: Int)] = [:]

    private var pending: [Pending] = []
    private var draining = false
    /// Pictures the latest frame is still waiting for (drawn meanwhile from another zoom).
    var pendingCount: Int { pending.count }
    /// Off: pictures a frame still needs are only drawn from another zoom, never rendered later
    /// (for tests that check the stand-ins, without leaving rendering running behind them).
    var rendersInBackground = true
    /// The camera is moving (a finger down, a pinch or a glide): nothing is rendered in the
    /// background meanwhile, so no frame of a gesture is spent rendering; it picks up when it stops.
    var interacting = false {
        didSet { if !interacting, oldValue { drain() } }
    }

    /// The pictures the latest frame still needs replace any older list (the camera may have moved
    /// on), and are rendered one per screen refresh; each one bumps `IslandRenderProgress` so the
    /// ground is drawn again with it.
    private func finish(_ queued: [Pending], _ deferMissing: Bool) {
        guard deferMissing, rendersInBackground else { return }
        // What this frame needs comes first; anything still waiting from before (warming ahead, a
        // chunk half made) stays behind it.
        let wanted = Set(queued.map { $0.key })
        pending = queued + pending.filter { !wanted.contains($0.key) }.prefix(48)
        drain()
    }

    /// Makes pictures waiting in the background for up to `seconds` now (while the island is still
    /// covered by the loading clouds, when a longer frame can't be seen). True if nothing is left.
    @discardableResult
    func drainFor(seconds: Double) -> Bool {
        let end = CACurrentMediaTime() + seconds
        while let next = pending.first, CACurrentMediaTime() < end {
            if images.object(forKey: next.key) != nil { pending.removeFirst(); partial[next.key] = nil; continue }
            if renderSlice(next) {
                if !pending.isEmpty, pending[0].key == next.key { pending.removeFirst() }
                IslandRenderProgress.shared.generation += 1
            }
        }
        return pending.isEmpty
    }

    /// For tests: makes everything waiting now, without waiting for frames.
    func drainNow() {
        while let next = pending.first {
            if images.object(forKey: next.key) != nil { pending.removeFirst(); partial[next.key] = nil; continue }
            if renderSlice(next), !pending.isEmpty, pending[0].key == next.key { pending.removeFirst() }
        }
    }

    /// Adds a picture to make in the background (if it isn't waiting already).
    private func enqueue(_ job: Pending) {
        guard rendersInBackground, !pending.contains(where: { $0.key == job.key }) else { return }
        pending.append(job)
        drain()
    }

    private func drain() {
        guard !pending.isEmpty, !draining, !interacting else { return }
        draining = true
        Task { @MainActor in
            while let next = self.pending.first, !self.interacting {
                if self.images.object(forKey: next.key) != nil {
                    self.pending.removeFirst()
                    self.partial[next.key] = nil
                    continue
                }
                // One slice this frame.
                if self.renderSlice(next) {
                    if !self.pending.isEmpty, self.pending[0].key == next.key { self.pending.removeFirst() }
                    IslandRenderProgress.shared.generation += 1
                }
                await FrameTicker.shared.nextFrame()
            }
            self.draining = false
        }
    }

    /// Renders the next slice of a picture over what's done so far. True when it's finished (and cached).
    private func renderSlice(_ job: Pending) -> Bool {
        let done = partial[job.key]
        let step = job.steps[done?.done ?? 0]
        let renderer = ImageRenderer(content: Canvas { c, _ in step(&c) }.frame(width: job.size.width, height: job.size.height))
        renderer.scale = job.scale
        #if DEBUG
        renders += 1
        #endif
        guard let layer = renderer.cgImage else { pending.removeFirst(); partial[job.key] = nil; return false }
        // Combining should never fail (plain 8-bit sRGB); if it did, start the picture again rather
        // than keep a part of it.
        var image = layer
        if let done {
            guard let both = Self.composite(done.image, layer) else { partial[job.key] = nil; return false }
            image = both
        }
        let count = (done?.done ?? 0) + 1
        guard count >= job.steps.count else { partial[job.key] = (image, count); return false }
        partial[job.key] = nil
        images.setObject(ImageBox(image), forKey: job.key, cost: image.bytesPerRow * image.height)
        return true
    }

    /// One picture drawn over another (same size), with plain Core Graphics.
    private static func composite(_ below: CGImage, _ above: CGImage) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: below.width, height: below.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let r = CGRect(x: 0, y: 0, width: below.width, height: below.height)
        ctx.draw(below, in: r)
        ctx.draw(above, in: r)
        return ctx.makeImage()
    }

    /// Far out, ground chunks (with the buildings baked in) are rendered at 1× instead of 2×: a
    /// quarter of the pixels, so a quarter of the time and memory, and too small on screen to tell.
    private func chunkScale(_ b: Bucket) -> CGFloat { b.baked ? 1 : renderScale }

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

    /// Drops every picture (for tests that render a lot, so they don't starve the rest of memory).
    func removeAll() {
        images.removeAllObjects()
        held = [:]
        pending = []
        partial = [:]
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

    private func render(key: NSString, size: CGSize, scale: CGFloat? = nil, draw: @escaping (inout GraphicsContext) -> Void) -> CGImage? {
        if let budget = renderBudget {
            guard budget > 0 else { skipped += 1; return nil }
            renderBudget = budget - 1
        }
        #if DEBUG
        renders += 1
        #endif
        let renderer = ImageRenderer(content: Canvas { c, _ in draw(&c) }.frame(width: size.width, height: size.height))
        renderer.scale = scale ?? renderScale
        guard let image = renderer.cgImage else { return nil }
        images.setObject(ImageBox(image), forKey: key, cost: image.bytesPerRow * image.height)
        return image
    }
}

/// Bumped whenever a picture the island was waiting for has been rendered in the background, so the
/// ground is drawn again with it.
@MainActor @Observable
final class IslandRenderProgress {
    static let shared = IslandRenderProgress()
    var generation = 0
}

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

    private init() { images.totalCostLimit = 160 * 1024 * 1024 }

    final class ImageBox {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }

    /// Zoom buckets: pictures are rendered at these zooms and scaled in between.
    static let buckets: [CGFloat] = [1, 1.25, 1.6, 2, 2.5, 3.2, 4]

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
    func frame(island: Island, size: CGSize, insets: EdgeInsets, zoom: CGFloat, quarter: Int, pan: CGSize,
               overrides: [Int: CGFloat], hidden: Set<Int>) -> Frame? {
        guard island.signature != 0, size.width > 0 else { return nil }
        let zb = Self.bucket(for: zoom)
        let lb = IslandLayout(island: island, size: size, insets: insets, zoom: zb, angle: CGFloat(quarter))
        let centre = CGPoint(x: insets.leading + (size.width - insets.leading - insets.trailing) / 2,
                             y: insets.top + (size.height - insets.top - insets.bottom) / 2)
        let k = zoom / zb
        func screen(_ r: CGRect) -> CGRect {
            CGRect(x: centre.x + (r.minX - centre.x) * k + pan.width, y: centre.y + (r.minY - centre.y) * k + pan.height,
                   width: r.width * k, height: r.height * k)
        }
        let view = CGRect(origin: .zero, size: size).insetBy(dx: -20, dy: -20)
        var frame = Frame()

        // Ground chunks.
        let groundKey = "g\(island.signature)|\(Int(lb.scale * 100))|\(quarter)|\(Int(size.width))x\(Int(size.height))"
        let bounds = groundBounds(island, layout: lb)
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
                    IslandPainter.drawTiles(&c, island: island, layout: lb.panned(CGSize(width: -rect.minX, height: -rect.minY)))
                }
                if let image { frame.ground.append((image, dest)) }
            }
        }

        // Places as pictures; everything else (and anything mid-reveal) item by item.
        let keys = placeContentKeys(island)
        var byPlot: [String: [Int]] = [:]
        var loose: [Int] = []
        for (i, item) in island.items.enumerated() where !hidden.contains(i) {
            if let key = item.plotKey, key != IslandPlacement.libraryKey, keys[key] != nil { byPlot[key, default: []].append(i) } else { loose.append(i) }
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
        let head = layout.u * 90
        return CGRect(x: xs.min()!, y: ys.min()! - head, width: ceil(xs.max()! - xs.min()!), height: ceil(ys.max()! - ys.min()! + head))
    }

    /// A key for each Place's contents (relative to its own corner), so moving it reuses its picture.
    private func placeContentKeys(_ island: Island) -> [String: Int] {
        if placeKeys.signature == island.signature { return placeKeys.keys }
        var hashers: [String: Hasher] = [:]
        let plots = Dictionary(island.allPlots.map { ($0.bookID, $0) }, uniquingKeysWith: { a, _ in a })
        for item in island.items {
            guard let key = item.plotKey, let plot = plots[key], key != IslandPlacement.libraryKey else { continue }
            var h = hashers[key] ?? { var h = Hasher(); h.combine(key); h.combine(plot.size); h.combine(plot.rotation); h.combine(plot.bay); return h }()
            h.combine(item.kind)
            h.combine(Int(((item.gx - CGFloat(plot.x)) * 1000).rounded()))
            h.combine(Int(((item.gy - CGFloat(plot.y)) * 1000).rounded()))
            h.combine(item.growth); h.combine(item.level); h.combine(item.turned); h.combine(item.facing); h.combine(item.seed)
            h.combine(item.progress); h.combine(item.total)
            hashers[key] = h
        }
        let keys = hashers.mapValues { $0.finalize() }
        placeKeys = (island.signature, keys)
        return keys
    }

    private func render(key: NSString, size: CGSize, draw: @escaping (inout GraphicsContext) -> Void) -> CGImage? {
        let renderer = ImageRenderer(content: Canvas { c, _ in draw(&c) }.frame(width: size.width, height: size.height))
        renderer.scale = renderScale
        guard let image = renderer.cgImage else { return nil }
        images.setObject(ImageBox(image), forKey: key, cost: image.bytesPerRow * image.height)
        return image
    }
}

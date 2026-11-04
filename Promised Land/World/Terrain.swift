import CoreGraphics
import Foundation

nonisolated enum TileKind: UInt8, Sendable {
    case ocean, sea, lake, river, land, road
    var isWater: Bool { self == .ocean || self == .sea || self == .lake || self == .river }
}

/// Everything the terrain generator needs, copied out of `WorldData` on the main actor.
nonisolated struct TerrainInputs: Sendable {
    let width: Int, height: Int
    let sea: [CGPoint]
    let islands: [Ellipse]
    let lakes: [Ellipse]
    let rivers: [[CGPoint]]
    let riverWidths: [Double]
    let roads: [[CGPoint]]
    let regions: [(bounds: GridRect, ground: RGB, desert: Bool, hills: Bool)]
    let footprints: [GridRect]

    @MainActor static func fromWorldData() -> TerrainInputs {
        TerrainInputs(
            width: WorldData.mapWidth, height: WorldData.mapHeight,
            sea: WorldData.mediterranean,
            islands: [WorldData.patmos],
            lakes: [WorldData.seaOfGalilee, WorldData.deadSea],
            rivers: WorldData.rivers.map(\.points), riverWidths: WorldData.rivers.map(\.width),
            roads: WorldData.roads,
            regions: WorldData.regions.map {
                ($0.bounds, RGB(hex: $0.ground),
                 ["egypt", "wilderness", "babylon"].contains($0.id),
                 ["prophets", "galilee", "kingdom"].contains($0.id))
            },
            footprints: WorldData.landmarks.map(\.footprint)
        )
    }
}

/// The generated terrain: per-tile kind and colour, plus the shapes the renderer strokes.
nonisolated struct TerrainModel: Sendable {
    let inputs: TerrainInputs
    let continent: [CGPoint]
    let kinds: [TileKind]
    let colors: [RGB]
    /// Tiles kept clear of decorations (landmark plots and their margins).
    let reserved: [Bool]

    var width: Int { inputs.width }
    var height: Int { inputs.height }

    func index(_ x: Int, _ y: Int) -> Int? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        return y * width + x
    }

    func kind(_ x: Int, _ y: Int) -> TileKind {
        index(x, y).map { kinds[$0] } ?? .ocean
    }

    func isLand(_ x: Int, _ y: Int) -> Bool { kind(x, y) == .land }

    static func generate(_ inputs: TerrainInputs) -> TerrainModel {
        let w = inputs.width, h = inputs.height

        // A soft, irregular coastline around the whole map.
        var outline: [CGPoint] = []
        func inset(_ t: Double, _ seed: UInt64) -> CGFloat { CGFloat(1.4 + 2.4 * Noise.value(t, 0, scale: 6, seed: seed)) }
        for x in stride(from: 0, to: w, by: 3) { outline.append(CGPoint(x: CGFloat(x), y: inset(Double(x), 11))) }
        for y in stride(from: 0, to: h, by: 3) { outline.append(CGPoint(x: CGFloat(w) - inset(Double(y), 12), y: CGFloat(y))) }
        for x in stride(from: w, to: 0, by: -3) { outline.append(CGPoint(x: CGFloat(x), y: CGFloat(h) - inset(Double(x), 13))) }
        for y in stride(from: h, to: 0, by: -3) { outline.append(CGPoint(x: inset(Double(y), 14), y: CGFloat(y))) }

        var kinds = [TileKind](repeating: .land, count: w * h)
        var colors = [RGB](repeating: .sand, count: w * h)
        var reserved = [Bool](repeating: false, count: w * h)

        for rect in inputs.footprints {
            for y in (rect.y - 1)...(rect.y + rect.h) {
                for x in (rect.x - 1)...(rect.x + rect.w) where x >= 0 && y >= 0 && x < w && y < h {
                    reserved[y * w + x] = true
                }
            }
        }

        for y in 0..<h {
            for x in 0..<w {
                let p = CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5)
                let i = y * w + x
                let onIsland = inputs.islands.contains { $0.contains(p.x, p.y) }

                // Kind
                var kind = TileKind.land
                var waterDistance = CGFloat.greatestFiniteMagnitude
                if !Geometry.contains(outline, p) {
                    kind = .ocean
                } else if Geometry.contains(inputs.sea, p) && !onIsland {
                    kind = .sea
                } else if inputs.lakes.contains(where: { $0.contains(p.x, p.y) }) {
                    kind = .lake
                } else {
                    for (river, width) in zip(inputs.rivers, inputs.riverWidths) {
                        let d = Geometry.distanceToPolyline(p, river) - width
                        if d < 0 { kind = .river }
                        waterDistance = min(waterDistance, max(0, d))
                    }
                    if kind == .land, inputs.roads.contains(where: { Geometry.distanceToPolyline(p, $0) < 0.45 }) {
                        kind = .road
                    }
                }
                kinds[i] = kind
                // Lakes and rivers keep a land colour underneath: their smooth shapes are stroked on top.
                guard kind != .ocean, kind != .sea else { colors[i] = .water; continue }

                // Distance to the nearest water, for green banks.
                for lake in inputs.lakes {
                    let nx = (p.x - lake.cx) / lake.rx, ny = (p.y - lake.cy) / lake.ry
                    waterDistance = min(waterDistance, max(0, (sqrt(nx * nx + ny * ny) - 1) * min(lake.rx, lake.ry)))
                }
                if !onIsland {
                    var closed = inputs.sea; closed.append(inputs.sea[0])
                    waterDistance = min(waterDistance, Geometry.distanceToPolyline(p, closed))
                }

                // Colour
                let region = inputs.regions.first { $0.bounds.contains(p.x, p.y) }
                var color = region?.ground ?? RGB.sand
                if waterDistance < 3.2 {
                    color = color.mixed(with: .olive, 0.55 * (1 - waterDistance / 3.2))
                }
                if region?.desert == true {
                    let dune = Noise.value(p.x, p.y * 1.6, scale: 4.5, seed: 21)
                    if dune > 0.62 { color = color.shifted(0.035) } else if dune < 0.3 { color = color.shifted(-0.03) }
                }
                if region?.hills == true {
                    let hill = Noise.value(p.x, p.y, scale: 5, seed: 22)
                    color = color.mixed(with: .olive, CGFloat(max(0, hill - 0.55)) * 0.5)
                }
                color = color.shifted(CGFloat(Noise.hash(x, y, seed: 7) - 0.5) * 0.018)
                colors[i] = color
            }
        }

        return TerrainModel(inputs: inputs, continent: outline, kinds: kinds, colors: colors, reserved: reserved)
    }
}

/// Wraps a CGImage so it can cross from the render queue to the main actor.
nonisolated struct RenderedImage: @unchecked Sendable {
    let image: CGImage
}

/// Draws a scene-space rectangle of terrain into a bitmap, in grid units under the iso transform.
nonisolated enum TerrainRenderer {
    static func render(_ model: TerrainModel, rect: CGRect, scale: CGFloat) -> RenderedImage? {
        let pw = Int(ceil(rect.width * scale)), ph = Int(ceil(rect.height * scale))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.setShouldAntialias(true)
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -rect.minX, y: -rect.minY)

        ctx.setFillColor(RGB.ocean.cgColor)
        ctx.fill(rect)

        let inputs = model.inputs
        let continent = Geometry.smoothClosedPath(model.continent)
        let sea = Geometry.smoothClosedPath(inputs.sea)

        // Visible grid range (with a margin for strokes).
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)].map(Iso.grid)
        let minX = max(0, Int(floor(corners.map(\.x).min()!)) - 2), maxX = min(model.width - 1, Int(ceil(corners.map(\.x).max()!)) + 2)
        let minY = max(0, Int(floor(corners.map(\.y).min()!)) - 2), maxY = min(model.height - 1, Int(ceil(corners.map(\.y).max()!)) + 2)
        guard minX <= maxX, minY <= maxY else { return ctx.makeImage().map(RenderedImage.init) }

        // Soft cliff under the land's edge, then the land itself.
        ctx.saveGState()
        ctx.translateBy(x: 0, y: -14)
        ctx.concatenate(Iso.transform)
        ctx.addPath(continent)
        ctx.setFillColor(RGB.stoneShade.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.concatenate(Iso.transform)

        ctx.saveGState()
        ctx.addPath(continent)
        ctx.clip()
        fillTiles(model, ctx, minX...maxX, minY...maxY) { _ in true }
        ctx.restoreGState()

        // Beach, sea, shallow band.
        stroke(ctx, sea, width: 1.4, color: RGB.beach.cgColor)
        ctx.addPath(sea)
        ctx.setFillColor(RGB.water.cgColor)
        ctx.fillPath()
        ctx.saveGState()
        ctx.addPath(sea); ctx.clip()
        stroke(ctx, sea, width: 2.6, color: RGB.shallow.cgColor)
        ctx.restoreGState()

        // Islands sit in the sea.
        for island in inputs.islands {
            let path = ellipsePath(island)
            ctx.addPath(ellipsePath(Ellipse(cx: island.cx, cy: island.cy, rx: island.rx + 0.9, ry: island.ry + 0.9)))
            ctx.setFillColor(RGB.shallow.cgColor); ctx.fillPath()
            ctx.addPath(ellipsePath(Ellipse(cx: island.cx, cy: island.cy, rx: island.rx + 0.4, ry: island.ry + 0.4)))
            ctx.setFillColor(RGB.beach.cgColor); ctx.fillPath()
            ctx.saveGState()
            ctx.addPath(path); ctx.clip()
            fillTiles(model, ctx, minX...maxX, minY...maxY) { island.contains(Double($0.x) + 0.5, Double($0.y) + 0.5, padding: 1) }
            ctx.restoreGState()
        }

        // Lakes with a beach rim and shallows.
        for lake in inputs.lakes {
            ctx.addPath(ellipsePath(Ellipse(cx: lake.cx, cy: lake.cy, rx: lake.rx + 0.45, ry: lake.ry + 0.45)))
            ctx.setFillColor(RGB.beach.cgColor); ctx.fillPath()
            ctx.addPath(ellipsePath(lake))
            ctx.setFillColor(RGB.shallow.cgColor); ctx.fillPath()
            ctx.addPath(ellipsePath(Ellipse(cx: lake.cx, cy: lake.cy, rx: lake.rx - 0.8, ry: lake.ry - 0.8)))
            ctx.setFillColor(RGB.water.cgColor); ctx.fillPath()
        }

        // Rivers.
        for (river, width) in zip(inputs.rivers, inputs.riverWidths) {
            let path = Geometry.smoothOpenPath(river)
            stroke(ctx, path, width: width * 2 + 0.35, color: RGB.beach.cgColor)
            stroke(ctx, path, width: width * 2, color: RGB.water.cgColor)
            stroke(ctx, path, width: width * 0.8, color: RGB.shallow.cgColor(alpha: 0.6))
        }

        // Roads (they cross rivers like little bridges).
        for road in inputs.roads {
            let path = Geometry.smoothOpenPath(road)
            stroke(ctx, path, width: 0.95, color: RGB.roadEdge.cgColor(alpha: 0.9))
            stroke(ctx, path, width: 0.7, color: RGB.road.cgColor)
        }
        ctx.restoreGState()

        return ctx.makeImage().map(RenderedImage.init)
    }

    private static func fillTiles(_ model: TerrainModel, _ ctx: CGContext, _ xs: ClosedRange<Int>, _ ys: ClosedRange<Int>,
                                  where include: ((x: Int, y: Int)) -> Bool) {
        for y in ys {
            for x in xs where include((x, y)) {
                guard let i = model.index(x, y) else { continue }
                let kind = model.kinds[i]
                let color = (kind == .ocean || kind == .sea) ? RGB.beach : model.colors[i]
                ctx.setFillColor(color.cgColor)
                ctx.fill(CGRect(x: CGFloat(x) - 0.02, y: CGFloat(y) - 0.02, width: 1.04, height: 1.04))
            }
        }
    }

    private static func stroke(_ ctx: CGContext, _ path: CGPath, width: CGFloat, color: CGColor) {
        ctx.addPath(path)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setStrokeColor(color)
        ctx.strokePath()
    }

    private static func ellipsePath(_ e: Ellipse) -> CGPath {
        CGPath(ellipseIn: CGRect(x: e.cx - e.rx, y: e.cy - e.ry, width: e.rx * 2, height: e.ry * 2), transform: nil)
    }
}

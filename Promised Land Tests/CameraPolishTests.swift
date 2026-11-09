import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import Promised_Land

/// Section 4d: the sea fills the screen at every zoom and turn, tap-to-zoom is one smooth move, the
/// selection ring stays under its building, and every layer works from the same zoom.
extension ImageRenderingTests {
@MainActor @Suite
struct CameraPolishTests {
    static let size = CGSize(width: 390, height: 844)
    static let island = LODTests.island

    @Test("The sea is textured to every edge of the screen when zoomed right out, at every turn", arguments: [0, 1, 2, 3])
    func seaFillsTheScreen(quarter: Int) {
        let screen = CGRect(origin: .zero, size: Self.size)
        let W = Int(Self.size.width), H = Int(Self.size.height)
        for zoom: CGFloat in [IslandLayout.minZoom * 0.75, 1, 1.6, 4] {
            for pan in [CGSize.zero, CGSize(width: 140, height: -90)] {
                let layout = IslandLayout(island: Self.island, size: Self.size, zoom: zoom, angle: CGFloat(quarter)).panned(pan)
                // The open sea alone, on nothing.
                let r = ImageRenderer(content: Canvas { c, _ in
                    IslandPainter.drawOpenSea(&c, island: Self.island, layout: layout, time: 0, visible: screen)
                }.frame(width: Self.size.width, height: Self.size.height))
                r.scale = 1
                let cg = r.cgImage!
                var buf = [UInt8](repeating: 0, count: W * H * 4)
                let ctx = CGContext(data: &buf, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                ctx.draw(cg, in: screen)
                // Wave marks in every part of the screen: no flat sea anywhere.
                let cell = 110
                for y0 in stride(from: 0, to: H - cell / 2, by: cell) {
                    for x0 in stride(from: 0, to: W - cell / 2, by: cell) {
                        var foam = 0
                        for y in y0..<min(H, y0 + cell) { for x in x0..<min(W, x0 + cell) where buf[(y * W + x) * 4 + 3] > 20 { foam += 1 } }
                        #expect(foam > 0, "flat sea at \(x0),\(y0) (zoom \(zoom), turn \(quarter))")
                    }
                }
                // The tiling is anchored to the island: it moves exactly with the camera.
                let moved = OpenSea.fill(layout: layout.panned(CGSize(width: 33, height: -21)))
                let here = OpenSea.fill(layout: layout)
                #expect(abs(moved.origin.x - here.origin.x - 33) < 0.001 && abs(moved.origin.y - here.origin.y + 21) < 0.001)
                #expect(moved.scale == here.scale)
            }
        }
        // The sea layer itself always covers the screen: drawn a step bigger and slid by at most a step.
        for p in stride(from: -300.0, through: 300, by: 37.3) {
            let slide = PanStep.offset(CGSize(width: p, height: -p))
            let canvas = PanStep.canvasSize(Self.size)
            #expect(slide.width <= 0 && slide.width + canvas.width >= Self.size.width)
            #expect(slide.height <= 0 && slide.height + canvas.height >= Self.size.height)
        }
    }

    @Test("Tap-to-zoom: one eased move of position and zoom together, ending exactly on target, no overshoot")
    func tapToZoom() {
        #expect((0.6...0.8).contains(PlatformScene.visitGlide))
        let target = (zoom: CGFloat(7.5), pan: CGSize(width: -420, height: 260))
        let glide = CameraGlide(fromZoom: 1.3, toZoom: target.zoom, fromPan: CGSize(width: 20, height: -10), toPan: target.pan,
                                start: 0, duration: PlatformScene.visitGlide)
        var last = glide.camera(at: 0)
        var steps: [CGFloat] = []
        for f in 1...Int(PlatformScene.visitGlide * 120) + 5 {
            let c = glide.camera(at: Double(f) / 120)
            // Never past the target, never backwards.
            #expect(c.zoom >= last.zoom && c.zoom <= target.zoom)
            #expect(c.pan.width <= last.pan.width && c.pan.width >= target.pan.width)
            #expect(c.pan.height >= last.pan.height && c.pan.height <= target.pan.height)
            steps.append(c.zoom - last.zoom)
            last = c
        }
        #expect(last.zoom == target.zoom && last.pan == target.pan)
        // Eased in and out: starts and ends gently, fastest in the middle; no single jump.
        let biggest = steps.max()!
        #expect(steps.first! < biggest / 4 && steps.filter { $0 > 0 }.last! < biggest / 4)
        #expect(biggest < (target.zoom - 1.3) / 40)
    }

    @Test("The selection ring stays on the ground: the building and its neighbours cover it, far out too")
    func ringUnderBuilding() throws {
        let zoom: CGFloat = 1.2
        let layout = IslandLayout(island: Self.island, size: Self.size, zoom: zoom)
        let frame = try #require(IslandRenderCache.shared.frame(island: Self.island, size: Self.size, insets: EdgeInsets(), zoom: zoom,
                                                                quarter: 0, pan: .zero, overrides: [:], hidden: []))
        #expect(frame.baked)   // far out: buildings are baked into the ground, the case that went wrong
        let ordered = Self.island.items.sorted { layout.depth($0.gx, $0.gy) < layout.depth($1.gx, $1.gy) }
        let screen = CGRect(origin: .zero, size: Self.size)
        let building = try #require(Self.island.items.first { $0.kind.isTall && $0.footprint.width >= 2
            && screen.insetBy(dx: 60, dy: 60).contains(layout.point($0.gx, $0.gy)) })
        func pixels(_ draw: @escaping (inout GraphicsContext) -> Void) -> [UInt8] {
            let r = ImageRenderer(content: Canvas { c, _ in draw(&c) }.frame(width: Self.size.width, height: Self.size.height))
            r.scale = 1
            let cg = r.cgImage!
            var buf = [UInt8](repeating: 0, count: Int(Self.size.width) * Int(Self.size.height) * 4)
            let ctx = CGContext(data: &buf, width: Int(Self.size.width), height: Int(Self.size.height), bitsPerComponent: 8,
                                bytesPerRow: Int(Self.size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(cg, in: CGRect(origin: .zero, size: Self.size))
            return buf
        }
        // The island with the ring drawn the way the ground layer draws it, and without.
        let ground: (inout GraphicsContext) -> Void = { c in for g in frame.ground { c.draw(Image(decorative: g.image, scale: 1), in: g.rect) } }
        let with = pixels { c in
            ground(&c)
            PlatformScene.drawHighlight(&c, building, layout: layout)
            var g = c
            g.clip(to: Path(ellipseIn: PlatformScene.highlightRect(building, layout: layout)))
            for over in PlatformScene.itemsOverRing(building, ordered: ordered, layout: layout) { IslandRenderCache.shared.drawItem(&g, over, layout: layout) }
        }
        let without = pixels { c in ground(&c) }
        let alone = pixels { c in IslandRenderCache.shared.drawItem(&c, building, layout: layout) }
        let ring = PlatformScene.highlightRect(building, layout: layout)
        var covered = 0, changedUnder = 0, showing = 0
        let W = Int(Self.size.width)
        for y in Int(ring.minY)..<Int(ring.maxY) {
            for x in Int(ring.minX)..<Int(ring.maxX) {
                let i = (y * W + x) * 4
                let d = abs(Int(with[i]) - Int(without[i])) + abs(Int(with[i + 1]) - Int(without[i + 1])) + abs(Int(with[i + 2]) - Int(without[i + 2]))
                if alone[i + 3] > 250 {
                    covered += 1
                    if d > 45 { changedUnder += 1 }    // the ring showing through the building
                } else if d > 12 { showing += 1 }      // the ring visible around its base
            }
        }
        #expect(covered > 20)
        #expect(Double(changedUnder) / Double(covered) < 0.05, "\(changedUnder) of \(covered) building pixels show the ring")
        #expect(showing > 0)
    }

    @Test("Every layer works from the same zoom, even pinched past the limits")
    func oneZoom() {
        let limit = IslandLayout.maxZoom(island: Self.island, size: Self.size)
        for m: CGFloat in [0.05, 0.2, 0.6, 1, 3, 9, 40] {
            let z = IslandLayout.clampedZoom(PlatformScene.rubberBand(2 * m, min: IslandLayout.minZoom, max: limit), maxZoom: limit)
            // The layout (people, buildings over them) uses exactly the camera's zoom, so the still
            // layers, scaled by the camera's zoom, never drift from it.
            #expect(IslandLayout(island: Self.island, size: Self.size, zoom: z).zoom == z)
        }
    }
}
}

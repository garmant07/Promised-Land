import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import Promised_Land

/// Section 4c: zoom and pan move smoothly, the scaled still drawing lines up with the camera, and
/// stepping up to a building fills the screen with it, centred, at every turn.
@MainActor
struct CameraFeelTests {
    static let size = CGSize(width: 390, height: 844)
    static let insets = EdgeInsets(top: 120, leading: 8, bottom: 118, trailing: 8)
    static let island = LODTests.island

    @Test("A wobbly pinch zooms smoothly, and the spot between the fingers stays put")
    func pinchIsSmooth() {
        var rng = SeededRandom(seed: 3)
        let anchor = CGPoint(x: 150, y: 400)
        let centre = IslandCamera.freeCentre(size: Self.size, insets: Self.insets)
        let from: (zoom: CGFloat, pan: CGSize) = (2, CGSize(width: 30, height: -20))
        let spot = IslandLayout(island: Self.island, size: Self.size, insets: Self.insets, zoom: from.zoom)
            .panned(from.pan).grid(anchor)
        var zoom = from.zoom
        var inputTurns = 0, outputTurns = 0
        var lastIn: CGFloat?, lastOut: CGFloat?, lastInStep: CGFloat = 0, lastOutStep: CGFloat = 0
        for i in 0..<120 {
            // The fingers spread steadily, with a wobble of up to ±4% each event.
            let magnification = (1 + CGFloat(i) / 60) * CGFloat(1 + rng.next(in: -0.04...0.04))
            let target = from.zoom * magnification
            zoom = PinchSmoothing.next(current: zoom, target: target)
            let pan = PlatformScene.panKeeping(anchor, from: from, toZoom: zoom, centre: centre)
            // The island point under the fingers doesn't move.
            let g = IslandLayout(island: Self.island, size: Self.size, insets: Self.insets, zoom: zoom).panned(pan).grid(anchor)
            #expect(abs(g.x - spot.x) < 0.001 && abs(g.y - spot.y) < 0.001)
            if let l = lastIn { let s = target - l; if s * lastInStep < 0 { inputTurns += 1 }; lastInStep = s }
            if let l = lastOut { let s = zoom - l; if s * lastOutStep < 0 { outputTurns += 1 }; lastOutStep = s }
            lastIn = target; lastOut = zoom
        }
        // The fingers' zoom jitters in and out; the island's far less.
        #expect(outputTurns * 2 < inputTurns, "in \(inputTurns), out \(outputTurns)")
    }

    @Test("A glide moves the camera smoothly however unevenly frames arrive, and lands exactly")
    func glideIsSmooth() {
        let glide = CameraGlide(fromZoom: 1.5, toZoom: 4, fromPan: .zero, toPan: CGSize(width: -300, height: 180),
                                start: 10, duration: 0.55, easeOut: true)
        var rng = SeededRandom(seed: 9)
        var t = 10.0
        var last = glide.camera(at: t)
        while !glide.isDone(at: t) {
            // 120 Hz frames, some late, some doubled up.
            let dt = [1.0 / 120, 1.0 / 60, 1.0 / 40][Int(rng.next(in: 0...2.99))]
            t += dt
            let c = glide.camera(at: t)
            // Always moving the same way, never back, and never more than its top speed allows.
            #expect(c.zoom >= last.zoom && c.pan.width <= last.pan.width && c.pan.height >= last.pan.height)
            #expect(abs(c.pan.width - last.pan.width) <= 300 * 3 / 0.55 * dt + 0.001)
            last = c
        }
        let end = glide.camera(at: t)
        #expect(end.zoom == 4 && end.pan == CGSize(width: -300, height: 180))
    }

    @Test("While zooming, the scaled still drawing lines up exactly with the camera", arguments: [0, 1, 2, 3])
    func stillLinesUp(quarter: Int) {
        let centre = IslandCamera.freeCentre(size: Self.size, insets: Self.insets)
        let z0: CGFloat = 2, p0 = CGSize(width: 40, height: -25)
        let drawn = IslandLayout(island: Self.island, size: Self.size, insets: Self.insets, zoom: z0, angle: CGFloat(quarter)).panned(p0)
        let anchor = PlatformScene.stillAnchor(centre: centre, pan: p0, size: Self.size)
        let a = CGPoint(x: anchor.x * Self.size.width, y: anchor.y * Self.size.height)
        for (z, p) in [(CGFloat(2.9), CGSize(width: 10, height: 5)), (1.4, CGSize(width: -60, height: 70)), (3.2, CGSize(width: 90, height: -40))] {
            let camera = IslandLayout(island: Self.island, size: Self.size, insets: Self.insets, zoom: z, angle: CGFloat(quarter)).panned(p)
            let s = z / z0
            for item in Self.island.items.prefix(60) {
                let q0 = drawn.point(item.gx, item.gy)
                // scaleEffect(s, anchor: a) then offset(p − p0), as the view applies them.
                let q = CGPoint(x: a.x + (q0.x - a.x) * s + (p.width - p0.width), y: a.y + (q0.y - a.y) * s + (p.height - p0.height))
                let want = camera.point(item.gx, item.gy)
                #expect(abs(q.x - want.x) < 0.01 && abs(q.y - want.y) < 0.01)
            }
        }
    }

    @Test("Stepping up to a building: its Place fills the screen's width, centred, at every turn", arguments: [0, 1, 2, 3])
    func visitFillsTheScreen(quarter: Int) {
        let area = Self.size.width - Self.insets.leading - Self.insets.trailing
        let centre = IslandCamera.freeCentre(size: Self.size, insets: Self.insets)
        for plot in Self.island.allPlots.prefix(30) {
            guard let item = Self.island.items.first(where: { $0.plotKey == plot.bookID }) else { continue }
            let zoom = IslandCamera.visitZoom(for: item, in: Self.island, size: Self.size, insets: Self.insets, quarter: quarter)
            let pan = IslandCamera.pan(toCentre: IslandCamera.focus(of: item, in: Self.island), island: Self.island, size: Self.size,
                                       insets: Self.insets, zoom: zoom, quarter: quarter)
            let l = IslandLayout(island: Self.island, size: Self.size, insets: Self.insets, zoom: zoom, angle: CGFloat(quarter)).panned(pan)
            let corners = [(plot.x, plot.y), (plot.x + plot.size, plot.y), (plot.x, plot.y + plot.size), (plot.x + plot.size, plot.y + plot.size)]
                .map { l.point(CGFloat($0.0), CGFloat($0.1)) }
            let width = corners.map(\.x).max()! - corners.map(\.x).min()!
            let mid = CGPoint(x: (corners.map(\.x).max()! + corners.map(\.x).min()!) / 2, y: (corners.map(\.y).max()! + corners.map(\.y).min()!) / 2)
            // Fills about three quarters of the width (less only if that's past the closest zoom).
            let capped = zoom >= IslandLayout(island: Self.island, size: Self.size, insets: Self.insets, angle: CGFloat(quarter)).maxZoom - 0.001
            #expect(capped || abs(width - IslandCamera.visitFill * area) < 1, "\(plot.bookID): \(width) of \(area)")
            #expect(width >= area * 0.5, "\(plot.bookID) only \(Int(width / area * 100))% wide")
            // Centred.
            #expect(abs(mid.x - centre.x) < 0.5 && abs(mid.y - centre.y) < 0.5)
        }
    }
}

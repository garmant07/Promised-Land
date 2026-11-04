import CoreGraphics
import Foundation

// One shared way of deciding what a tap touched, used by the island and the world map.
//
// 1. Convert the touch to the scene's coordinates (the caller does this).
// 2. Each object offers its ground footprint (did the tap land on its tile?) and the bounds
//    of what is actually drawn (its visible pixels, not the transparent padding).
// 3. Objects are checked in reverse depth order: whatever is drawn in front wins.
// 4. Small objects are at least 44pt to hit.

/// Something a tap could select.
nonisolated struct HitCandidate<ID: Hashable>: Sendable where ID: Sendable {
    let id: ID
    /// Higher draws in front.
    let depth: CGFloat
    /// The tap is on this object's ground tile(s).
    let onGround: Bool
    /// The visible drawing, in the same coordinates as the tap.
    let bounds: CGRect
}

nonisolated enum HitPicker {
    /// - Parameters:
    ///   - point: the tap, in scene coordinates.
    ///   - minimumTarget: smallest hit area, in scene units (44pt at the current zoom).
    /// - Returns: the front-most object whose ground or drawing is under the tap; failing
    ///   that, the front-most small object whose 44pt target covers it.
    static func pick<ID>(_ point: CGPoint, from candidates: [HitCandidate<ID>], minimumTarget: CGFloat) -> ID? {
        func rank(_ c: HitCandidate<ID>) -> (CGFloat, CGFloat) {
            (c.depth, -hypot(point.x - c.bounds.midX, point.y - c.bounds.midY))
        }
        let direct = candidates.filter { $0.onGround || $0.bounds.contains(point) }
        if let best = direct.max(by: { rank($0) < rank($1) }) { return best.id }
        let near = candidates.filter { expanded($0.bounds, to: minimumTarget).contains(point) }
        return near.max(by: { rank($0) < rank($1) })?.id
    }

    /// Grows a rectangle to at least `size` on each side, keeping its centre.
    static func expanded(_ r: CGRect, to size: CGFloat) -> CGRect {
        let w = max(r.width, size), h = max(r.height, size)
        return CGRect(x: r.midX - w / 2, y: r.midY - h / 2, width: w, height: h)
    }
}

/// Tells taps from pans: a touch is a tap only if it never moved 10pt or more from where
/// it started. Panning therefore never selects anything.
nonisolated struct TapTracker: Sendable {
    static let slop: CGFloat = 10
    private var start: CGPoint?
    private(set) var moved = false

    mutating func began(at p: CGPoint) { start = p; moved = false }

    mutating func moved(to p: CGPoint) {
        guard let start else { return }
        if hypot(p.x - start.x, p.y - start.y) >= Self.slop { moved = true }
    }

    /// True if the touch that just ended counts as a tap.
    mutating func ended(at p: CGPoint) -> Bool {
        moved(to: p)
        defer { start = nil }
        return start != nil && !moved
    }
}

/// Finds the visible (non-transparent) part of an image, as a unit rect (y down from the top).
nonisolated enum OpaqueBounds {
    static func unitRect(of image: CGImage) -> CGRect {
        let side = 64
        guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue),
              let data = ctx.data else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        let pixels = data.bindMemory(to: UInt8.self, capacity: side * side)
        var minX = side, minY = side, maxX = -1, maxY = -1
        for row in 0..<side {
            for col in 0..<side where pixels[row * side + col] > 24 {
                minX = min(minX, col); maxX = max(maxX, col)
                minY = min(minY, row); maxY = max(maxY, row)
            }
        }
        guard maxX >= 0 else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        // Bitmap rows run top to bottom in memory.
        return CGRect(x: CGFloat(minX) / CGFloat(side), y: CGFloat(minY) / CGFloat(side),
                      width: CGFloat(maxX - minX + 1) / CGFloat(side), height: CGFloat(maxY - minY + 1) / CGFloat(side))
    }
}

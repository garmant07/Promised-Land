import CoreGraphics
import Foundation

// One shared way of deciding what a tap touched, used by the island and the world map.

nonisolated struct HitRegion: Sendable {
    struct Part: Sendable {
        let bounds: CGRect
        let alpha: [UInt8]?
    }

    let bounds: CGRect
    let parts: [Part]

    init(bounds: CGRect, alpha: [UInt8]? = nil) {
        self.bounds = bounds
        self.parts = [Part(bounds: bounds, alpha: alpha)]
    }

    init(parts: [Part]) {
        self.parts = parts
        self.bounds = parts.dropFirst().reduce(parts.first?.bounds ?? .zero) { $0.union($1.bounds) }
    }

    func contains(_ point: CGPoint) -> Bool {
        parts.contains { part in
            guard part.bounds.contains(point) else { return false }
            guard let alpha = part.alpha else { return true }
            let x = min(63, max(0, Int(((point.x - part.bounds.minX) / part.bounds.width) * 64)))
            let y = min(63, max(0, Int(((point.y - part.bounds.minY) / part.bounds.height) * 64)))
            return alpha[y * 64 + x] > 24
        }
    }
}

nonisolated struct HitCandidate<ID: Hashable>: Sendable where ID: Sendable {
    let id: ID
    let depth: CGFloat
    let onGround: Bool
    let bounds: CGRect
    let art: HitRegion?
    let allowsFallback: Bool

    init(id: ID, depth: CGFloat, onGround: Bool, bounds: CGRect,
         art: HitRegion? = nil, allowsFallback: Bool = true) {
        self.id = id
        self.depth = depth
        self.onGround = onGround
        self.bounds = bounds
        self.art = art
        self.allowsFallback = allowsFallback
    }

    func isDirect(at point: CGPoint) -> Bool {
        onGround || (art?.contains(point) ?? bounds.contains(point))
    }
}

nonisolated enum HitPicker {
    private static func rank<ID>(_ point: CGPoint, _ c: HitCandidate<ID>) -> (CGFloat, CGFloat) {
        (c.depth, -hypot(point.x - c.bounds.midX, point.y - c.bounds.midY))
    }

    static func direct<ID>(_ point: CGPoint, from candidates: [HitCandidate<ID>]) -> ID? {
        candidates.filter { $0.isDirect(at: point) }
            .max { rank(point, $0) < rank(point, $1) }?.id
    }

    static func fallback<ID>(_ point: CGPoint, from candidates: [HitCandidate<ID>], minimumTarget: CGFloat) -> ID? {
        candidates.filter { $0.allowsFallback && expanded($0.bounds, to: minimumTarget).contains(point) }
            .max { rank(point, $0) < rank(point, $1) }?.id
    }

    /// Returns the closest permitted fallback, used after all direct targets were checked.
    static func nearestFallback<ID>(_ point: CGPoint, from candidates: [HitCandidate<ID>], minimumTarget: CGFloat) -> ID? {
        candidates.filter { $0.allowsFallback && expanded($0.bounds, to: minimumTarget).contains(point) }
            .min { hypot(point.x - $0.bounds.midX, point.y - $0.bounds.midY)
                < hypot(point.x - $1.bounds.midX, point.y - $1.bounds.midY) }?.id
    }

    /// Returns a direct hit first, then a permitted minimum-size fallback.
    static func pick<ID>(_ point: CGPoint, from candidates: [HitCandidate<ID>], minimumTarget: CGFloat) -> ID? {
        direct(point, from: candidates) ?? nearestFallback(point, from: candidates, minimumTarget: minimumTarget)
    }

    /// Grows a rectangle to at least size on each side, keeping its centre.
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
        return CGRect(x: CGFloat(minX) / CGFloat(side), y: CGFloat(minY) / CGFloat(side),
                      width: CGFloat(maxX - minX + 1) / CGFloat(side), height: CGFloat(maxY - minY + 1) / CGFloat(side))
    }

    static func alphaMask(of image: CGImage) -> [UInt8] {
        let side = 64
        guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue),
              let data = ctx.data else { return Array(repeating: 255, count: side * side) }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        return Array(UnsafeBufferPointer(start: data.bindMemory(to: UInt8.self, capacity: side * side),
                                         count: side * side))
    }
}

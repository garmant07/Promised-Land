import CoreGraphics
import Foundation

/// Isometric projection between grid coordinates and SpriteKit scene coordinates.
///
/// Grid x runs west → east, grid y north → south. In the scene (y up), the grid
/// origin sits at the top corner and tiles are 64 × 32 points.
nonisolated enum Iso {
    static let tileWidth: CGFloat = 64
    static let tileHeight: CGFloat = 32

    /// grid → scene, as an affine transform (lets Core Graphics draw in grid units).
    static let transform = CGAffineTransform(a: tileWidth / 2, b: -tileHeight / 2,
                                             c: -tileWidth / 2, d: -tileHeight / 2, tx: 0, ty: 0)

    static func scene(_ gx: CGFloat, _ gy: CGFloat) -> CGPoint {
        CGPoint(x: (gx - gy) * tileWidth / 2, y: -(gx + gy) * tileHeight / 2)
    }

    static func scene(_ p: CGPoint) -> CGPoint { scene(p.x, p.y) }

    static func grid(_ p: CGPoint) -> CGPoint {
        let a = p.x / (tileWidth / 2)      // gx - gy
        let b = -p.y / (tileHeight / 2)    // gx + gy
        return CGPoint(x: (a + b) / 2, y: (b - a) / 2)
    }

    /// Depth for sprites: things further south (lower on screen) draw in front.
    static func depth(_ gx: CGFloat, _ gy: CGFloat) -> CGFloat {
        100 + (gx + gy) * 0.5
    }

    /// The scene-space rectangle containing the whole map.
    static func sceneBounds(width: Int, height: Int) -> CGRect {
        let w = CGFloat(width), h = CGFloat(height)
        return CGRect(x: -h * tileWidth / 2, y: -(w + h) * tileHeight / 2,
                      width: (w + h) * tileWidth / 2, height: (w + h) * tileHeight / 2)
    }
}

/// A plain colour that is safe to use off the main thread.
nonisolated struct RGB: Sendable, Hashable {
    var r: CGFloat, g: CGFloat, b: CGFloat

    init(r: CGFloat, g: CGFloat, b: CGFloat) { self.r = r; self.g = g; self.b = b }

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        r = CGFloat((value >> 16) & 0xFF) / 255
        g = CGFloat((value >> 8) & 0xFF) / 255
        b = CGFloat(value & 0xFF) / 255
    }

    func mixed(with other: RGB, _ t: CGFloat) -> RGB {
        let t = max(0, min(1, t))
        return RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    func shifted(_ amount: CGFloat) -> RGB {
        RGB(r: max(0, min(1, r + amount)), g: max(0, min(1, g + amount)), b: max(0, min(1, b + amount)))
    }

    var cgColor: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: 1) }
    func cgColor(alpha: CGFloat) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: alpha) }

    // Palette (mirrors Theme.swift, usable off the main thread).
    static let sand = RGB(hex: "#F3DFB5")
    static let stoneLight = RGB(hex: "#F4D6AA")
    static let stoneShade = RGB(hex: "#E8C192")
    static let terracotta = RGB(hex: "#E39A7E")
    static let lavender = RGB(hex: "#BFA9DA")
    static let olive = RGB(hex: "#A9B47C")
    static let oliveDeep = RGB(hex: "#929E66")
    static let cream = RGB(hex: "#FAF0DE")
    static let brown = RGB(hex: "#7A4A2A")
    static let trunk = RGB(hex: "#A9805C")
    static let water = RGB(hex: "#A9CDD3")
    static let waterDeep = RGB(hex: "#93BEC6")
    static let shallow = RGB(hex: "#C2DEDC")
    static let ocean = RGB(hex: "#9CC3CC")
    static let beach = RGB(hex: "#F7E7C4")
    static let wheat = RGB(hex: "#E9C77F")
    static let road = RGB(hex: "#F6E3C0")
    static let roadEdge = RGB(hex: "#E5C79D")
}

/// Deterministic hashing and value noise so the world never changes between launches.
nonisolated enum Noise {
    static func hash(_ x: Int, _ y: Int, seed: UInt64 = 0x5EED) -> Double {
        var h = UInt64(bitPattern: Int64(x)) &* 0x9E3779B97F4A7C15
        h ^= UInt64(bitPattern: Int64(y)) &* 0xC2B2AE3D27D4EB4F
        h ^= seed &* 0x165667B19E3779F9
        h ^= h >> 31; h &*= 0xBF58476D1CE4E5B9; h ^= h >> 27; h &*= 0x94D049BB133111EB; h ^= h >> 31
        return Double(h >> 11) / Double(1 << 53)
    }

    /// Smooth value noise in [0, 1).
    static func value(_ x: Double, _ y: Double, scale: Double, seed: UInt64 = 1) -> Double {
        let fx = x / scale, fy = y / scale
        let ix = Int(floor(fx)), iy = Int(floor(fy))
        let tx = fx - floor(fx), ty = fy - floor(fy)
        let sx = tx * tx * (3 - 2 * tx), sy = ty * ty * (3 - 2 * ty)
        let a = hash(ix, iy, seed: seed), b = hash(ix + 1, iy, seed: seed)
        let c = hash(ix, iy + 1, seed: seed), d = hash(ix + 1, iy + 1, seed: seed)
        return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy
    }
}

/// Small fixed-seed random generator (SplitMix64).
nonisolated struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

nonisolated enum Geometry {
    static func distanceToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        let t = len2 == 0 ? 0 : max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        return hypot(p.x - a.x - t * dx, p.y - a.y - t * dy)
    }

    static func distanceToPolyline(_ p: CGPoint, _ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return .greatestFiniteMagnitude }
        var best = CGFloat.greatestFiniteMagnitude
        for i in 0..<(points.count - 1) { best = min(best, distanceToSegment(p, points[i], points[i + 1])) }
        return best
    }

    static func contains(_ polygon: [CGPoint], _ p: CGPoint) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let a = polygon[i], b = polygon[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    /// A smooth closed path through the points (Catmull-Rom), for soft coastlines.
    static func smoothClosedPath(_ pts: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        let n = pts.count
        guard n > 2 else { return path }
        path.move(to: pts[0])
        for i in 0..<n {
            let p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }

    /// A smooth open path through the points.
    static func smoothOpenPath(_ pts: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = pts.first else { return path }
        path.move(to: first)
        guard pts.count > 2 else { pts.dropFirst().forEach { path.addLine(to: $0) }; return path }
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(i + 2, pts.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }
}

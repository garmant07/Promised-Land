import SpriteKit
import UIKit

/// Cross-reference roads between landmarks, built stone by stone (or plank by plank over water).
final class ConnectionLayer: SKNode {
    private var roads: [String: SKNode] = [:]
    private var paths: [String: [CGPoint]] = [:]   // grid-space samples
    private(set) var built: Set<String> = []

    override init() {
        super.init()
        zPosition = 2 // above terrain, below every building
        for connection in WorldData.connections {
            paths[connection.id] = Self.samples(for: connection)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Shows roads for active connections immediately (no animation).
    func show(_ ids: Set<String>, terrain: TerrainModel?) {
        for id in ids where roads[id] == nil {
            let node = makeRoad(id, terrain: terrain)
            addChild(node)
            roads[id] = node
            built.insert(id)
        }
        removeRoads(notIn: ids)
    }

    /// Builds one road with an animation; returns its total duration.
    @discardableResult
    func animateIn(_ id: String, terrain: TerrainModel?) -> TimeInterval {
        guard roads[id] == nil else { return 0 }
        let node = makeRoad(id, terrain: terrain)
        addChild(node)
        roads[id] = node
        built.insert(id)
        let step = min(0.05, 2.4 / Double(max(node.children.count, 1)))
        for (i, piece) in node.children.enumerated() {
            piece.alpha = 0
            piece.setScale(0.2)
            let appear = SKAction.group([.fadeIn(withDuration: 0.25), .scale(to: 1, duration: 0.3)])
            appear.timingMode = .easeOut
            piece.run(.sequence([.wait(forDuration: Double(i) * step), appear]))
        }
        return Double(node.children.count) * step + 0.3
    }

    func removeRoads(notIn ids: Set<String>) {
        for (id, node) in roads where !ids.contains(id) {
            node.removeFromParent()
            roads[id] = nil
            built.remove(id)
        }
    }

    /// The connection whose road passes near a grid point, if any.
    func connection(near grid: CGPoint) -> String? {
        var best: (String, CGFloat)?
        for id in roads.keys {
            guard let samples = paths[id] else { continue }
            let d = Geometry.distanceToPolyline(grid, samples)
            if d < 0.9, d < (best?.1 ?? .greatestFiniteMagnitude) { best = (id, d) }
        }
        return best?.0
    }

    /// Midpoint and length (grid units) of a road, for framing the camera.
    func frame(of id: String) -> (mid: CGPoint, length: CGFloat)? {
        guard let samples = paths[id], let first = samples.first, let last = samples.last else { return nil }
        return (samples[samples.count / 2], hypot(last.x - first.x, last.y - first.y))
    }

    // MARK: Building

    /// A gentle curve between the two landmarks, sampled about every 1.1 tiles.
    private static func samples(for connection: Connection) -> [CGPoint] {
        guard let a = WorldData.landmark(bookID: connection.a)?.center,
              let b = WorldData.landmark(bookID: connection.b)?.center else { return [] }
        let dx = b.x - a.x, dy = b.y - a.y
        let length = hypot(dx, dy)
        // Bend sideways a little, with a fixed direction per connection so it never changes.
        let bend: CGFloat = (connection.id.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 2 == 0 ? 1 : -1) * min(8, length * 0.12)
        let control = CGPoint(x: (a.x + b.x) / 2 - dy / length * bend, y: (a.y + b.y) / 2 + dx / length * bend)
        let count = max(2, Int(length / 1.1))
        return (0...count).map { i in
            let t = CGFloat(i) / CGFloat(count)
            let u = 1 - t
            return CGPoint(x: u * u * a.x + 2 * u * t * control.x + t * t * b.x,
                           y: u * u * a.y + 2 * u * t * control.y + t * t * b.y)
        }
    }

    private func makeRoad(_ id: String, terrain: TerrainModel?) -> SKNode {
        let node = SKNode()
        node.name = "road:\(id)"
        guard let samples = paths[id] else { return node }
        // Skip the ends that sit under the landmarks themselves.
        let trimmed = samples.dropFirst(2).dropLast(2)
        for (i, p) in trimmed.enumerated() {
            let overWater = terrain.map { $0.kind(Int(p.x), Int(p.y)).isWater } ?? false
            let piece = SKSpriteNode(texture: overWater ? Self.plank : Self.stone)
            piece.size = piece.texture!.size()
            piece.position = Iso.scene(p)
            piece.zPosition = CGFloat(i) * 0.001
            if overWater {
                // Align planks across the direction of travel.
                let g = i + 2 // index into `samples` (two were trimmed from the start)
                let next = samples[min(samples.count - 1, g + 1)], prev = samples[max(0, g - 1)]
                let a = Iso.scene(next), b = Iso.scene(prev)
                piece.zRotation = atan2(a.y - b.y, a.x - b.x) + .pi / 2
            }
            node.addChild(piece)
        }
        return node
    }

    // MARK: Textures

    private static let stone: SKTexture = {
        let size = CGSize(width: 52, height: 30)
        let format = UIGraphicsImageRendererFormat(); format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(RGB.roadEdge.cgColor(alpha: 0.9))
            c.fillEllipse(in: CGRect(x: 2, y: 5, width: 48, height: 23))
            c.setFillColor(RGB(hex: "#F4DCA8").cgColor)
            c.fillEllipse(in: CGRect(x: 3, y: 2, width: 46, height: 22))
            c.setFillColor(RGB.lavender.cgColor(alpha: 0.55))
            c.fillEllipse(in: CGRect(x: 22, y: 9, width: 8, height: 5))
        }
        return SKTexture(image: image)
    }()

    private static let plank: SKTexture = {
        let size = CGSize(width: 46, height: 14)
        let format = UIGraphicsImageRendererFormat(); format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(RGB.trunk.shifted(-0.05).cgColor)
            c.addPath(CGPath(roundedRect: CGRect(x: 1, y: 4, width: 44, height: 9), cornerWidth: 4, cornerHeight: 4, transform: nil))
            c.fillPath()
            c.setFillColor(RGB.trunk.shifted(0.12).cgColor)
            c.addPath(CGPath(roundedRect: CGRect(x: 1, y: 1, width: 44, height: 9), cornerWidth: 4, cornerHeight: 4, transform: nil))
            c.fillPath()
        }
        return SKTexture(image: image)
    }()
}

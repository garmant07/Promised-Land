import SpriteKit
import SwiftUI

// MARK: - Your avatar on the map

/// Your character, walking gently between the places you've begun.
final class PlayerAvatarNode: SKSpriteNode {
    private(set) var isWalking = false
    private var shownAvatar: Avatar?

    init() {
        super.init(texture: nil, color: .clear, size: CGSize(width: 26, height: 47))
        name = "player"
        anchorPoint = CGPoint(x: 0.5, y: 0.06)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    var grid: CGPoint { Iso.grid(position) }

    /// Draws the SwiftUI figure into a texture (only when the look changes).
    func show(_ avatar: Avatar) {
        guard avatar != shownAvatar else { return }
        shownAvatar = avatar
        let renderer = ImageRenderer(content: AvatarFigure(avatar: avatar).frame(width: 26, height: 47))
        renderer.scale = 3
        if let image = renderer.uiImage { texture = SKTexture(image: image) }
    }

    /// Walks through grid points in turn at a gentle pace, then calls `done`.
    func walk(through points: [CGPoint], tilesPerSecond: CGFloat = 1.5, done: (() -> Void)? = nil) {
        removeAction(forKey: "walk")
        var steps: [SKAction] = []
        var from = grid
        for p in points {
            let distance = hypot(p.x - from.x, p.y - from.y)
            guard distance > 0.05 else { continue }
            let duration = TimeInterval(min(9, max(0.4, distance / tilesPerSecond)))
            let target = Iso.scene(p)
            let faceLeft = target.x < Iso.scene(from).x
            steps.append(.run { [weak self] in self?.xScale = faceLeft ? -1 : 1 })
            let move = SKAction.move(to: target, duration: duration)
            move.timingMode = .easeInEaseOut
            let bob = SKAction.repeat(.sequence([.moveBy(x: 0, y: 2, duration: 0.17), .moveBy(x: 0, y: -2, duration: 0.17)]),
                                      count: max(1, Int(duration / 0.34)))
            steps.append(.group([move, bob]))
            from = p
        }
        isWalking = true
        run(.sequence(steps + [.run { [weak self] in self?.isWalking = false; done?() }]), withKey: "walk")
    }

    func stop() {
        removeAction(forKey: "walk")
        isWalking = false
    }
}

// MARK: - Journeys

/// Dotted story routes with stop markers that light up as their chapters are read.
final class JourneyLayer: SKNode {
    private var routes: [String: SKNode] = [:]
    private var markers: [String: [SKShapeNode]] = [:]

    override init() {
        super.init()
        zPosition = 4 // above terrain and roads, below buildings
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Shows a journey once any of its stops is lit (progressive disclosure).
    func apply(_ progress: GameProgress) {
        for journey in JourneyData.visible {
            let lit = progress.litCount(journey)
            if lit == 0 {
                routes.removeValue(forKey: journey.id)?.removeFromParent()
                markers[journey.id] = nil
                continue
            }
            if routes[journey.id] == nil { build(journey) }
            for (i, stop) in journey.stops.enumerated() { style(markers[journey.id]?[i], lit: progress.isLit(stop)) }
        }
    }

    private func build(_ journey: Journey) {
        let node = SKNode()
        let points = journey.stops.map { Iso.scene($0.grid) }
        let path = Geometry.smoothOpenPath(points)
        let dashed = path.copy(dashingWithPhase: 0, lengths: [10, 9])
        let line = SKShapeNode(path: dashed)
        line.strokeColor = UIColor(Color.lavender).withAlphaComponent(0.85)
        line.lineWidth = 4
        line.lineCap = .round
        node.addChild(line)
        var stopNodes: [SKShapeNode] = []
        for p in points {
            let marker = SKShapeNode(circleOfRadius: 10)
            marker.position = p
            marker.lineWidth = 3
            node.addChild(marker)
            stopNodes.append(marker)
        }
        addChild(node)
        routes[journey.id] = node
        markers[journey.id] = stopNodes
    }

    private func style(_ marker: SKShapeNode?, lit: Bool) {
        guard let marker else { return }
        marker.fillColor = lit ? UIColor(Color.wheat) : UIColor(Color.cream).withAlphaComponent(0.85)
        marker.strokeColor = lit ? UIColor(Color.terracotta) : UIColor(Color.lavender)
        marker.glowWidth = lit ? 4 : 0
    }

    /// A little pulse when a stop lights up.
    func pulse(journey id: String, stop index: Int) {
        guard let marker = markers[id]?[safe: index] else { return }
        marker.run(.sequence([.scale(to: 1.6, duration: 0.25), .scale(to: 1, duration: 0.3)]))
    }

    /// The journey whose stop marker is nearest a grid point (within a tile).
    func journey(near grid: CGPoint) -> String? {
        for journey in JourneyData.visible where routes[journey.id] != nil {
            if journey.stops.contains(where: { hypot($0.x - grid.x, $0.y - grid.y) < 1.1 }) { return journey.id }
        }
        return nil
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

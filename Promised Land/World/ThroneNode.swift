import SpriteKit

/// The throne room at the New Jerusalem (on Patmos). Appears once the whole Bible has been read.
final class ThroneNode: SKSpriteNode {
    static let gridX = 13, gridY = 44, size = 2
    static var center: CGPoint { CGPoint(x: Double(gridX) + Double(size) / 2, y: Double(gridY) + Double(size) / 2) }

    init() {
        super.init(texture: nil, color: .clear, size: .zero)
        name = "throne"
        position = Iso.scene(Self.center)
        zPosition = Iso.depth(CGFloat(Self.gridX + Self.size), CGFloat(Self.gridY + Self.size)) + 0.05
        isHidden = true
        if let art = LandmarkPainter.canvas(size: Self.size, scale: 2.5, draw: { $0.throneRoom() }) {
            texture = SKTexture(cgImage: art.image)
            self.size = art.pointSize
            anchorPoint = art.anchor
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func contains(gridPoint g: CGPoint) -> Bool {
        !isHidden && g.x >= CGFloat(Self.gridX) - 0.3 && g.x <= CGFloat(Self.gridX + Self.size) + 0.3 &&
            g.y >= CGFloat(Self.gridY) - 0.3 && g.y <= CGFloat(Self.gridY + Self.size) + 0.3
    }
}

nonisolated extension Painter {
    /// A small glowing hall with a golden dome.
    func throneRoom() {
        glow()
        groundPatch()
        box(pt(0, 8), w: 70, h: 30, top: .cream, left: .cream, right: Painter.creamShade)
        for i in 0..<4 {
            let x = -28 + CGFloat(i) * 8, y = 14 + CGFloat(i) * 4
            rounded(CGRect(x: c.x + x * u - 1.6 * u, y: c.y + y * u - 22 * u, width: 3.2 * u, height: 22 * u), radius: 1.6 * u, .wheat)
        }
        rounded(CGRect(x: c.x + 6 * u, y: c.y + 2 * u, width: 10 * u, height: 16 * u), radius: 5 * u, .wheat, alpha: 0.7)
        _ = dome(pt(0, -22), r: 20, color: Painter.gold)
        ellipse(pt(0, -46), 7, 7, .cream)
    }
}

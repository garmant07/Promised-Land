import SpriteKit

/// The Library: appears on the map after the first journal entry. Tapping it opens your journals.
final class LibraryNode: SKSpriteNode {
    /// Where it stands (a free spot in the Promised Land, near the coast).
    static let gridX = 36, gridY = 28, size = 3
    static var center: CGPoint { CGPoint(x: Double(gridX) + Double(size) / 2, y: Double(gridY) + Double(size) / 2) }

    init() {
        super.init(texture: nil, color: .clear, size: .zero)
        name = "library"
        position = Iso.scene(Self.center)
        zPosition = Iso.depth(CGFloat(Self.gridX + Self.size), CGFloat(Self.gridY + Self.size)) + 0.05
        isHidden = true
        if let art = LandmarkPainter.canvas(size: Self.size, scale: 2, draw: { $0.libraryBuilding() }) {
            texture = SKTexture(cgImage: art.image)
            self.size = art.pointSize
            anchorPoint = art.anchor
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func contains(gridPoint g: CGPoint) -> Bool {
        !isHidden && g.x >= CGFloat(Self.gridX) - 0.2 && g.x <= CGFloat(Self.gridX + Self.size) + 0.2 &&
            g.y >= CGFloat(Self.gridY) - 0.2 && g.y <= CGFloat(Self.gridY + Self.size) + 0.2
    }
}

nonisolated extension Painter {
    /// A small columned library with a lavender roof and a row of book-spine windows.
    func libraryBuilding() {
        groundPatch()
        shadow(pt(0, 8), 100)
        box(pt(0, 8), w: 74, h: 30, top: .cream, left: .cream, right: Painter.creamShade)
        // Book spines in the windows
        let spines: [RGB] = [.terracotta, .lavender, .olive, .wheat, RGB(hex: "#93AECF"), .terracotta]
        for (i, color) in spines.enumerated() {
            let x = -32 + CGFloat(i) * 5
            rounded(CGRect(x: c.x + x * u, y: c.y + (CGFloat(i) * 2.5 - 14) * u, width: 3.6 * u, height: 12 * u), radius: u, color)
        }
        for (i, color) in spines.reversed().enumerated() {
            let x = 6 + CGFloat(i) * 5
            rounded(CGRect(x: c.x + x * u, y: c.y + (12 - CGFloat(i) * 2.5 - 14) * u, width: 3.6 * u, height: 12 * u), radius: u, color.shifted(-0.05))
        }
        // Columns at the front corner, and a door
        for i in 0..<3 {
            let x = -18 + CGFloat(i) * 9, y = 16 + CGFloat(i) * 4.5
            rounded(CGRect(x: c.x + x * u - 1.6 * u, y: c.y + y * u - 20 * u, width: 3.2 * u, height: 20 * u), radius: 1.6 * u, .cream)
        }
        rounded(CGRect(x: c.x + 6 * u, y: c.y + 4 * u, width: 9 * u, height: 14 * u), radius: 4.5 * u, .brown, alpha: 0.22)
        roof(pt(0, -22), w: 74, rise: 22, left: .lavender, right: Painter.lavDark)
        tree(pt(-50, 10), 0.7)
        cypress(pt(48, 8), 0.8)
    }
}

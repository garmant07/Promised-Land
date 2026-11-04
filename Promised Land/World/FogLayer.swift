import SpriteKit
import UIKit

/// A soft cream fog over each region that hasn't been read in yet.
final class FogLayer: SKNode {
    private var fogs: [String: SKSpriteNode] = [:]
    private(set) var revealed: Set<String> = []
    private var configured = false

    override init() {
        super.init()
        // Each fog sprite is depth-sorted just behind its region's back corner, so buildings
        // from regions in front draw over it. Plots inside a fogged region are dimmed instead.
        zPosition = 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Creates fog for every region not yet revealed (no animation).
    func configure(revealed initial: Set<String>) {
        guard !configured else { return }
        configured = true
        revealed = initial
        for region in WorldData.regions where !initial.contains(region.id) {
            let sprite = makeFog(for: region)
            addChild(sprite)
            fogs[region.id] = sprite
        }
    }

    /// Lifts the fog over newly revealed regions; returns their ids.
    @discardableResult
    func reveal(_ now: Set<String>, animated: Bool) -> [String] {
        guard configured else { configure(revealed: now); return [] }
        let newly = now.subtracting(revealed)
        revealed.formUnion(now)
        // Regions can be fogged again after "reset progress".
        for region in WorldData.regions where !now.contains(region.id) && fogs[region.id] == nil {
            let sprite = makeFog(for: region)
            sprite.alpha = 0
            addChild(sprite)
            sprite.run(.fadeIn(withDuration: 0.6))
            fogs[region.id] = sprite
            revealed.remove(region.id)
        }
        for id in newly {
            guard let sprite = fogs.removeValue(forKey: id) else { continue }
            if animated {
                let fade = SKAction.group([.fadeOut(withDuration: 1.4), .scale(to: 1.08, duration: 1.4)])
                fade.timingMode = .easeOut
                sprite.run(.sequence([fade, .removeFromParent()]))
            } else {
                sprite.removeFromParent()
            }
        }
        return Array(newly)
    }

    func isFogged(_ regionID: String) -> Bool { fogs[regionID] != nil }

    // MARK: Drawing

    private func makeFog(for region: Region) -> SKSpriteNode {
        let b = region.bounds
        let margin: CGFloat = 1.2
        let corners = [CGPoint(x: CGFloat(b.x) - margin, y: CGFloat(b.y) - margin),
                       CGPoint(x: CGFloat(b.x + b.w) + margin, y: CGFloat(b.y) - margin),
                       CGPoint(x: CGFloat(b.x + b.w) + margin, y: CGFloat(b.y + b.h) + margin),
                       CGPoint(x: CGFloat(b.x) - margin, y: CGFloat(b.y + b.h) + margin)].map(Iso.scene)
        let pad: CGFloat = 60
        let minX = corners.map(\.x).min()! - pad, maxX = corners.map(\.x).max()! + pad
        let minY = corners.map(\.y).min()! - pad, maxY = corners.map(\.y).max()! + pad
        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        // Drawn tiny and scaled up: the bilinear filtering makes the edges soft.
        let scale: CGFloat = 0.06
        let pw = max(4, Int(rect.width * scale)), ph = max(4, Int(rect.height * scale))
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.scaleBy(x: CGFloat(pw) / rect.width, y: CGFloat(ph) / rect.height)
        ctx.translateBy(x: -rect.minX, y: -rect.minY)
        let path = CGMutablePath()
        path.addLines(between: corners)
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setFillColor(RGB.cream.cgColor(alpha: 0.78))
        ctx.fillPath()
        // Puffs give it a cloudy texture.
        var rng = SeededRandom(seed: region.id.unicodeScalars.reduce(UInt64(99)) { $0 &* 31 &+ UInt64($1.value) })
        for _ in 0..<(b.w * b.h / 18) {
            let gx = CGFloat(b.x) + CGFloat.random(in: 0...CGFloat(b.w), using: &rng)
            let gy = CGFloat(b.y) + CGFloat.random(in: 0...CGFloat(b.h), using: &rng)
            let p = Iso.scene(gx, gy)
            let r = CGFloat.random(in: 60...140, using: &rng)
            let shade = Bool.random(using: &rng) ? RGB.cream : RGB.sand
            ctx.setFillColor(shade.cgColor(alpha: 0.18))
            ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r * 0.5, width: r * 2, height: r))
        }
        let texture = SKTexture(cgImage: ctx.makeImage()!)
        texture.filteringMode = .linear

        let sprite = SKSpriteNode(texture: texture, size: rect.size)
        sprite.anchorPoint = .zero
        sprite.position = rect.origin
        sprite.name = "fog:\(region.id)"
        sprite.zPosition = Iso.depth(CGFloat(b.x), CGFloat(b.y)) - 1

        // Region name floats on its fog.
        let label = SKSpriteNode(texture: LabelTexture.make(region.name, size: 22, emphasis: true))
        label.size = label.texture!.size()
        let centre = Iso.scene(CGPoint(x: region.bounds.center.x, y: CGFloat(region.bounds.y) + 1.5))
        label.position = CGPoint(x: centre.x - rect.minX, y: centre.y - rect.minY)
        label.alpha = 0.75
        sprite.addChild(label)

        sprite.run(.repeatForever(.sequence([.fadeAlpha(to: 0.9, duration: 3), .fadeAlpha(to: 1, duration: 3)])))
        return sprite
    }
}

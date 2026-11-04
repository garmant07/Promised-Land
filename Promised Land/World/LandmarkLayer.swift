import SpriteKit
import SwiftUI
import UIKit

/// All 66 landmark sprites, their labels, and the celebration effects.
final class LandmarkLayer: SKNode {
    /// Labels live in a separate layer so they can sit above the fog.
    let labelLayer = SKNode()

    private var sprites: [String: SKSpriteNode] = [:]
    private var labels: [String: SKSpriteNode] = [:]
    private var looks: [String: LandmarkLook] = [:]
    private var textures: [LandmarkLook: (texture: SKTexture, size: CGSize, anchor: CGPoint)] = [:]
    private var pendingLooks: Set<LandmarkLook> = []

    override init() {
        super.init()
        labelLayer.zPosition = 6_000
        for landmark in WorldData.landmarks { addLandmark(landmark) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func addLandmark(_ landmark: Landmark) {
        let sprite = SKSpriteNode()
        sprite.name = "landmark:\(landmark.bookID)"
        sprite.position = Iso.scene(landmark.center)
        sprite.zPosition = Iso.depth(CGFloat(landmark.x + landmark.size), CGFloat(landmark.y + landmark.size))
        addChild(sprite)
        sprites[landmark.bookID] = sprite
        setLook(LandmarkLook(style: landmark.style, stage: .plot, level: .base, size: landmark.size),
                for: landmark.bookID, animated: false)

        if let book = landmark.book {
            let label = SKSpriteNode(texture: LabelTexture.make(book.name))
            label.size = label.texture!.size()
            // On the lower half of the plot, so it's clear which building it names.
            let centre = Iso.scene(landmark.center)
            label.position = CGPoint(x: centre.x, y: centre.y - CGFloat(landmark.size) * Iso.tileHeight * 0.3)
            label.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            labelLayer.addChild(label)
            labels[landmark.bookID] = label
        }
    }

    // MARK: Progress

    /// Updates every landmark to match progress. Returns books whose look changed.
    @discardableResult
    func apply(_ progress: GameProgress, animated: Bool) -> [String] {
        var changed: [String] = []
        for landmark in WorldData.landmarks {
            // Under fog, plots are drawn faint (the fog sits behind them in depth order).
            let fogged = !progress.isRegionRevealed(landmark.regionID)
            let alpha: CGFloat = fogged ? 0.45 : 1
            if let sprite = sprites[landmark.bookID], sprite.alpha != alpha {
                sprite.run(.fadeAlpha(to: alpha, duration: animated ? 0.8 : 0))
            }
            let look = LandmarkLook(style: landmark.style, stage: progress.stage(of: landmark.bookID),
                                    level: progress.level(of: landmark.bookID), size: landmark.size,
                                    read: progress.chaptersRead(landmark.bookID),
                                    total: landmark.book?.chapterCount ?? 1)
            if looks[landmark.bookID] != look {
                setLook(look, for: landmark.bookID, animated: animated)
                changed.append(landmark.bookID)
            }
        }
        return changed
    }

    private func setLook(_ look: LandmarkLook, for bookID: String, animated: Bool) {
        let previous = looks[bookID]
        looks[bookID] = look
        guard let sprite = sprites[bookID] else { return }
        if let cached = textures[look] {
            install(cached, on: sprite)
            if animated, let previous, previous.stage != look.stage || previous.level != look.level {
                bounce(sprite)
                puff(at: sprite.position, z: sprite.zPosition + 0.1, big: false)
            }
            return
        }
        // Plots are tiny to draw: do them now. Buildings render off the main thread.
        if look.stage == .plot {
            if let image = LandmarkPainter.render(look, scale: 1.5) { cache(image, look: look); install(textures[look]!, on: sprite) }
            return
        }
        guard !pendingLooks.contains(look) else { return }
        pendingLooks.insert(look)
        let scale: CGFloat = look.size >= 6 ? 1.3 : 2
        Task.detached(priority: .userInitiated) { [weak self] in
            let image = LandmarkPainter.render(look, scale: scale)
            await self?.finishRender(image, look: look, animated: animated)
        }
    }

    private func finishRender(_ image: LandmarkImage?, look: LandmarkLook, animated: Bool) {
        pendingLooks.remove(look)
        guard let image else { return }
        cache(image, look: look)
        for (bookID, current) in looks where current == look {
            guard let sprite = sprites[bookID], let entry = textures[look] else { continue }
            install(entry, on: sprite)
            if animated {
                bounce(sprite)
                puff(at: sprite.position, z: sprite.zPosition + 0.1, big: false)
            }
        }
    }

    private func cache(_ image: LandmarkImage, look: LandmarkLook) {
        let texture = SKTexture(cgImage: image.image)
        textures[look] = (texture, image.pointSize, image.anchor)
        // Looks change with every chapter, so drop textures no landmark shows any more.
        if textures.count > 120 {
            let inUse = Set(looks.values)
            for key in textures.keys where !inUse.contains(key) && key.stage != .plot { textures[key] = nil }
        }
    }

    private func install(_ entry: (texture: SKTexture, size: CGSize, anchor: CGPoint), on sprite: SKSpriteNode) {
        sprite.texture = entry.texture
        sprite.size = entry.size
        sprite.anchorPoint = entry.anchor
    }

    // MARK: Effects

    private func bounce(_ sprite: SKSpriteNode) {
        sprite.removeAction(forKey: "bounce")
        let up = SKAction.scale(to: 1.08, duration: 0.16); up.timingMode = .easeOut
        let down = SKAction.scale(to: 1.0, duration: 0.28); down.timingMode = .easeInEaseOut
        sprite.run(.sequence([up, down]), withKey: "bounce")
    }

    /// A soft burst of dust (or confetti for a celebration).
    func puff(at point: CGPoint, z: CGFloat, big: Bool) {
        let colors: [UIColor] = big
            ? [UIColor(Color.wheat), UIColor(Color.terracotta), UIColor(Color.lavender), UIColor(Color.olive)]
            : [UIColor(Color.stoneShade), UIColor(Color.sand)]
        for color in colors {
            let emitter = SKEmitterNode()
            emitter.particleTexture = ParticleTexture.dot
            emitter.numParticlesToEmit = big ? 22 : 10
            emitter.particleBirthRate = big ? 120 : 80
            emitter.particleLifetime = big ? 1.6 : 0.9
            emitter.particleLifetimeRange = 0.4
            emitter.emissionAngle = .pi / 2
            emitter.emissionAngleRange = big ? .pi * 0.9 : .pi * 2
            emitter.particleSpeed = big ? 160 : 50
            emitter.particleSpeedRange = 60
            emitter.yAcceleration = big ? -160 : 10
            emitter.particleAlphaSpeed = big ? -0.55 : -1.1
            emitter.particleScale = big ? 1.0 : 0.7
            emitter.particleScaleRange = 0.3
            emitter.particleColor = color
            emitter.particleColorBlendFactor = 1
            emitter.particlePositionRange = CGVector(dx: 40, dy: 14)
            emitter.position = CGPoint(x: point.x, y: point.y + (big ? 30 : 0))
            emitter.zPosition = z
            addChild(emitter)
            emitter.run(.sequence([.wait(forDuration: 2.5), .removeFromParent()]))
        }
    }

    /// Plays the "building complete" moment.
    func celebrate(_ bookID: String) {
        guard let sprite = sprites[bookID] else { return }
        bounce(sprite)
        puff(at: sprite.position, z: 5_500, big: true)
    }

    // MARK: Hit testing & labels

    func landmark(at scenePoint: CGPoint) -> String? {
        let g = Iso.grid(scenePoint)
        if let hit = WorldData.landmarks.first(where: {
            g.x >= CGFloat($0.x) - 0.3 && g.x <= CGFloat($0.x + $0.size) + 0.3 &&
            g.y >= CGFloat($0.y) - 0.3 && g.y <= CGFloat($0.y + $0.size) + 0.3
        }) {
            return hit.bookID
        }
        // Tall buildings: accept taps on the drawn shape above the footprint.
        let candidates = sprites.filter { (bookID, sprite) in
            guard looks[bookID]?.stage != .plot, sprite.frame.contains(scenePoint) else { return false }
            let footprintCentre = sprite.position
            return scenePoint.y > footprintCentre.y && abs(scenePoint.x - footprintCentre.x) < sprite.size.width * 0.3
        }
        return candidates.max { $0.value.zPosition < $1.value.zPosition }?.key
    }

    /// Keeps labels readable at any zoom, and hides them when zoomed far out.
    func updateLabels(zoom: CGFloat) {
        let scale = min(2.4, max(0.75, zoom * 0.95))
        let alpha: CGFloat = zoom > 3.3 ? 0 : (zoom > 2.8 ? (3.3 - zoom) * 2 : 1)
        for label in labels.values {
            label.setScale(scale)
            label.alpha = alpha
        }
    }

    func sprite(for bookID: String) -> SKSpriteNode? { sprites[bookID] }
}

// MARK: - Small textures

enum ParticleTexture {
    static let dot: SKTexture = {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 2, y: 2, width: 12, height: 12))
        }
        return SKTexture(image: image)
    }()
}

/// A rounded cream pill with serif text, as a texture.
enum LabelTexture {
    static func make(_ text: String, size: CGFloat = 12, emphasis: Bool = false) -> SKTexture {
        let base = UIFont.systemFont(ofSize: size, weight: emphasis ? .bold : .semibold)
        let font = base.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) } ?? base
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(Color.bodyText)]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let padding = CGSize(width: size * 0.8, height: size * 0.35)
        let canvas = CGSize(width: ceil(textSize.width + padding.width * 2), height: ceil(textSize.height + padding.height * 2))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { _ in
            let pill = UIBezierPath(roundedRect: CGRect(origin: .zero, size: canvas), cornerRadius: canvas.height / 2)
            UIColor(Color.cream).withAlphaComponent(emphasis ? 0.0 : 0.88).setFill()
            pill.fill()
            (text as NSString).draw(at: CGPoint(x: padding.width, y: padding.height), withAttributes: attributes)
        }
        return SKTexture(image: image)
    }
}

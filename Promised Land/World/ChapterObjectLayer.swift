import SpriteKit

/// Story objects built by reading particular chapters (see ChapterLandmarks.swift).
final class ChapterObjectLayer: SKNode {
    private var sprites: [String: SKSpriteNode] = [:]
    private var looks: [String: ChapterObjectLook] = [:]
    private var textures: [ChapterObjectLook: (texture: SKTexture, size: CGSize, anchor: CGPoint)] = [:]
    private var pending: Set<ChapterObjectLook> = []

    /// Updates every visible story object to match progress. Returns ids whose depth increased.
    @discardableResult
    func apply(_ progress: GameProgress, animated: Bool) -> [String] {
        var grown: [String] = []
        for entry in ChapterLandmarks.visible {
            let depth = progress.depth(of: entry)
            guard depth > 0 else {
                sprites.removeValue(forKey: entry.id)?.removeFromParent()
                looks[entry.id] = nil
                continue
            }
            let look = ChapterObjectLook(kind: entry.kind, depth: depth, variant: entry.variant, size: entry.size)
            guard looks[entry.id] != look else { continue }
            if (looks[entry.id]?.depth ?? 0) < depth { grown.append(entry.id) }
            looks[entry.id] = look
            show(entry, look: look, animated: animated)
        }
        return grown
    }

    private func show(_ entry: ChapterLandmark, look: ChapterObjectLook, animated: Bool) {
        let sprite = sprites[entry.id] ?? {
            let node = SKSpriteNode()
            node.name = "story:\(entry.id)"
            node.position = Iso.scene(entry.center)
            node.zPosition = Iso.depth(CGFloat(entry.x + entry.size), CGFloat(entry.y + entry.size)) + 0.05
            addChild(node)
            sprites[entry.id] = node
            return node
        }()
        if let cached = textures[look] {
            install(cached, on: sprite, animated: animated)
            return
        }
        guard !pending.contains(look) else { return }
        pending.insert(look)
        Task.detached(priority: .userInitiated) { [weak self] in
            let image = ChapterObjectPainter.render(look, scale: look.size >= 3 ? 2 : 2.5)
            await self?.finish(image, look: look, animated: animated)
        }
    }

    private func finish(_ image: LandmarkImage?, look: ChapterObjectLook, animated: Bool) {
        pending.remove(look)
        guard let image else { return }
        let entry = (SKTexture(cgImage: image.image), image.pointSize, image.anchor)
        textures[look] = entry
        for (id, current) in looks where current == look {
            if let sprite = sprites[id] { install(entry, on: sprite, animated: animated) }
        }
    }

    private func install(_ entry: (texture: SKTexture, size: CGSize, anchor: CGPoint), on sprite: SKSpriteNode, animated: Bool) {
        sprite.texture = entry.texture
        sprite.size = entry.size
        sprite.anchorPoint = entry.anchor
        guard animated else { return }
        sprite.setScale(0.6)
        let grow = SKAction.scale(to: 1.0, duration: 0.45)
        grow.timingMode = .easeOut
        sprite.run(grow)
    }

    /// Tap candidates: each placed story object's footprint and visible drawing.
    func hitCandidates(at scenePoint: CGPoint) -> [HitCandidate<WorldHit>] {
        let g = Iso.grid(scenePoint)
        return ChapterLandmarks.visible.compactMap { entry in
            guard let sprite = sprites[entry.id], !sprite.isHidden else { return nil }
            return HitCandidate(id: .story(entry.id), depth: sprite.zPosition,
                                onGround: WorldHitBounds.onFootprint(g, x: entry.x, y: entry.y, size: entry.size),
                                bounds: WorldHitBounds.visibleFrame(of: sprite))
        }
    }

    func sprite(for id: String) -> SKSpriteNode? { sprites[id] }

    func position(of id: String) -> CGPoint? { sprites[id]?.position }

    /// A little grow-in, played when the camera arrives at a new or deeper object.
    func pop(_ id: String) {
        guard let sprite = sprites[id] else { return }
        sprite.removeAction(forKey: "pop")
        sprite.setScale(0.55)
        let grow = SKAction.scale(to: 1.06, duration: 0.35)
        grow.timingMode = .easeOut
        let settle = SKAction.scale(to: 1.0, duration: 0.2)
        settle.timingMode = .easeInEaseOut
        sprite.run(.sequence([grow, settle]), withKey: "pop")
    }
}

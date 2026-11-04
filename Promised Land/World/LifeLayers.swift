import SpriteKit
import UIKit

// MARK: - Decorations

/// Trees, rocks and bushes, placed by a fixed seed and attached only near the camera.
final class DecorationLayer: SKNode {
    private enum Kind: CaseIterable { case olive, cypress, bush, rock, palm }

    private struct Item {
        let kind: Kind
        let gx: CGFloat, gy: CGFloat
        let scale: CGFloat
        let regionID: String?
    }

    private let bucketSize = 16
    private var bucketColumns = 0
    private var buckets: [Int: [Item]] = [:]
    private var attached: [Int: SKNode] = [:]
    private var fogged: Set<String> = []
    private(set) var itemCount = 0

    func build(_ terrain: TerrainModel) {
        guard buckets.isEmpty else { return }
        bucketColumns = (terrain.width + bucketSize - 1) / bucketSize
        let deserts: Set<String> = ["egypt", "wilderness", "babylon"]
        let hills: Set<String> = ["prophets", "galilee", "kingdom"]

        func nearWater(_ x: Int, _ y: Int) -> Bool {
            for dy in -2...2 { for dx in -2...2 where terrain.kind(x + dx, y + dy).isWater && terrain.kind(x + dx, y + dy) != .ocean { return true } }
            return false
        }

        for y in 0..<terrain.height {
            for x in 0..<terrain.width {
                guard terrain.kind(x, y) == .land, let i = terrain.index(x, y), !terrain.reserved[i] else { continue }
                let r = Noise.hash(x, y, seed: 42)
                let pick = Noise.hash(x, y, seed: 43)
                let region = WorldData.regions.first { $0.bounds.contains(Double(x) + 0.5, Double(y) + 0.5) }
                let id = region?.id ?? ""
                var kind: Kind?
                if nearWater(x, y) {
                    if r < 0.17 { kind = pick < 0.6 ? .olive : .bush }
                } else if deserts.contains(id) {
                    if r < 0.03 { kind = .rock } else if r < 0.045 { kind = .palm } else if r < 0.06 { kind = .bush }
                } else if hills.contains(id) {
                    if r < 0.05 { kind = .cypress } else if r < 0.1 { kind = .olive } else if r < 0.12 { kind = .rock }
                } else if id == "eden" {
                    if r < 0.15 { kind = .olive } else if r < 0.21 { kind = .bush }
                } else {
                    if r < 0.03 { kind = .bush } else if r < 0.05 { kind = .rock } else if r < 0.06 { kind = .olive }
                }
                guard let kind else { continue }
                let jx = CGFloat(Noise.hash(x, y, seed: 44) - 0.5) * 0.6
                let jy = CGFloat(Noise.hash(x, y, seed: 45) - 0.5) * 0.6
                let item = Item(kind: kind, gx: CGFloat(x) + 0.5 + jx, gy: CGFloat(y) + 0.5 + jy,
                                scale: 0.85 + CGFloat(Noise.hash(x, y, seed: 46)) * 0.3, regionID: region?.id)
                buckets[(y / bucketSize) * bucketColumns + x / bucketSize, default: []].append(item)
                itemCount += 1
            }
        }
    }

    /// Attaches buckets near the view (a couple per frame, to avoid hitches) and drops the rest.
    /// Returns true if more buckets are still waiting to be attached.
    @discardableResult
    func update(visible: CGRect) -> Bool {
        guard bucketColumns > 0 else { return false }
        let area = visible.insetBy(dx: -200, dy: -200)
        let corners = [CGPoint(x: area.minX, y: area.minY), CGPoint(x: area.maxX, y: area.minY),
                       CGPoint(x: area.minX, y: area.maxY), CGPoint(x: area.maxX, y: area.maxY)].map(Iso.grid)
        let bx0 = max(0, Int(corners.map(\.x).min()!) / bucketSize), bx1 = Int(max(0, corners.map(\.x).max()!)) / bucketSize
        let by0 = max(0, Int(corners.map(\.y).min()!) / bucketSize), by1 = Int(max(0, corners.map(\.y).max()!)) / bucketSize
        var wanted: Set<Int> = []
        if bx0 <= bx1, by0 <= by1 {
            for by in by0...by1 { for bx in bx0...min(bx1, bucketColumns - 1) { wanted.insert(by * bucketColumns + bx) } }
        }
        var budget = 2
        var morePending = false
        for key in wanted where attached[key] == nil {
            guard let items = buckets[key] else { continue }
            guard budget > 0 else { morePending = true; break }
            budget -= 1
            let node = SKNode()
            for item in items {
                let sprite = SKSpriteNode(texture: texture(item.kind))
                sprite.size = sprite.texture!.size()
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0.12)
                sprite.position = Iso.scene(item.gx, item.gy)
                sprite.zPosition = Iso.depth(item.gx, item.gy)
                sprite.setScale(item.scale)
                sprite.name = item.regionID
                sprite.alpha = item.regionID.map { fogged.contains($0) } == true ? 0 : 1
                node.addChild(sprite)
            }
            addChild(node)
            attached[key] = node
        }
        for (key, node) in attached where !wanted.contains(key) {
            node.removeFromParent()
            attached[key] = nil
        }
        return morePending
    }

    /// Decorations in fogged regions stay hidden; they fade in when the fog lifts.
    func setFogged(_ regions: Set<String>, animated: Bool) {
        fogged = regions
        for node in attached.values {
            for case let sprite as SKSpriteNode in node.children {
                let target: CGFloat = sprite.name.map { regions.contains($0) } == true ? 0 : 1
                guard sprite.alpha != target else { continue }
                if animated {
                    sprite.run(.sequence([.wait(forDuration: Double.random(in: 0.3...1.4)), .fadeAlpha(to: target, duration: 0.6)]))
                } else {
                    sprite.alpha = target
                }
            }
        }
    }

    private func texture(_ kind: Kind) -> SKTexture {
        switch kind {
        case .olive: SpriteArt.olive
        case .cypress: SpriteArt.cypress
        case .bush: SpriteArt.bush
        case .rock: SpriteArt.rock
        case .palm: SpriteArt.palm
        }
    }
}

// MARK: - Characters

/// Characters who appear once their landmark is complete, and wander nearby.
final class CharacterLayer: SKNode {
    private var nodes: [String: SKSpriteNode] = [:]

    /// Makes the characters present match the set of books given (no animation).
    func sync(present books: Set<String>) {
        for character in WorldData.characters {
            if books.contains(character.bookID) {
                if nodes[character.id] == nil { spawn(character, animated: false) }
            } else if let node = nodes.removeValue(forKey: character.id) {
                node.removeFromParent()
            }
        }
    }

    /// Characters arriving at a newly completed landmark.
    func arrive(for bookID: String) {
        for character in WorldData.characters where character.bookID == bookID && nodes[character.id] == nil {
            spawn(character, animated: true)
        }
    }

    private func spawn(_ character: WorldCharacter, animated: Bool) {
        guard let landmark = WorldData.landmark(bookID: character.bookID) else { return }
        let sprite: SKSpriteNode
        if let image = UIImage(named: character.imageName) {
            let texture = SKTexture(image: image)
            sprite = SKSpriteNode(texture: texture)
            let aspect = image.size.width / max(image.size.height, 1)
            sprite.size = CGSize(width: 48 * aspect, height: 48)
        } else {
            sprite = SKSpriteNode(texture: SpriteArt.placeholderFigure(robe: RGB(hex: character.robe)))
            sprite.size = CGSize(width: 26, height: 47)
        }
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.08)
        sprite.name = "character:\(character.id)"
        let index = landmark.characters.firstIndex(of: character) ?? 0
        let start = CGPoint(x: CGFloat(landmark.x + landmark.size) + 0.6,
                            y: CGFloat(landmark.y) + CGFloat(landmark.size) * (0.3 + 0.25 * CGFloat(index)))
        sprite.position = Iso.scene(start)
        sprite.zPosition = Iso.depth(start.x, start.y) + 0.2
        addChild(sprite)
        nodes[character.id] = sprite
        if animated {
            sprite.alpha = 0
            sprite.position.y += 40
            let drop = SKAction.group([.fadeIn(withDuration: 0.4), .moveBy(x: 0, y: -40, duration: 0.5)])
            drop.timingMode = .easeOut
            sprite.run(drop)
        }
        wander(sprite, around: landmark, delay: animated ? 0.8 : Double(index) * 0.7)
    }

    /// Short, slow walks to random spots around (not on) the landmark's plot.
    private func wander(_ sprite: SKSpriteNode, around landmark: Landmark, delay: TimeInterval) {
        let step = SKAction.run { [weak sprite] in
            guard let sprite else { return }
            let here = Iso.grid(sprite.position)
            var target = here
            for _ in 0..<12 {
                let gx = CGFloat(landmark.x) - 1.4 + CGFloat.random(in: 0...(CGFloat(landmark.size) + 2.8))
                let gy = CGFloat(landmark.y) - 1.4 + CGFloat.random(in: 0...(CGFloat(landmark.size) + 2.8))
                let inside = gx > CGFloat(landmark.x) - 0.2 && gx < CGFloat(landmark.x + landmark.size) + 0.2 &&
                             gy > CGFloat(landmark.y) - 0.2 && gy < CGFloat(landmark.y + landmark.size) + 0.2
                if !inside, hypot(gx - here.x, gy - here.y) < 3.5 { target = CGPoint(x: gx, y: gy); break }
            }
            let distance = hypot(target.x - here.x, target.y - here.y)
            let destination = Iso.scene(target)
            sprite.xScale = abs(sprite.xScale) * (destination.x < sprite.position.x ? -1 : 1)
            let walk = SKAction.move(to: destination, duration: TimeInterval(max(0.6, distance / 0.55)))
            walk.timingMode = .easeInEaseOut
            let bob = SKAction.repeat(.sequence([.moveBy(x: 0, y: 1.5, duration: 0.18), .moveBy(x: 0, y: -1.5, duration: 0.18)]),
                                      count: Int(max(1, distance / 0.55 / 0.36)))
            sprite.run(.group([walk, bob]), withKey: "walk")
        }
        let loop = SKAction.repeatForever(.sequence([step, .wait(forDuration: 4.5, withRange: 4)]))
        sprite.run(.sequence([.wait(forDuration: delay), loop]), withKey: "wander")
    }

    /// Keeps characters sorted correctly against buildings as they walk.
    func updateDepths() {
        for sprite in nodes.values {
            let g = Iso.grid(sprite.position)
            sprite.zPosition = Iso.depth(g.x, g.y) + 0.2
        }
    }

    func character(at scenePoint: CGPoint) -> WorldCharacter? {
        let hit = nodes.first { $0.value.frame.insetBy(dx: -10, dy: -8).contains(scenePoint) }
        return hit.flatMap { id in WorldData.characters.first { $0.id == id.key } }
    }

    /// Shows a speech bubble above a character for a few seconds.
    func speak(_ character: WorldCharacter, zoom: CGFloat) {
        guard let sprite = nodes[character.id] else { return }
        sprite.childNode(withName: "bubble")?.removeFromParent()
        let bubble = SKSpriteNode(texture: SpriteArt.speechBubble(line: character.line, name: character.name))
        bubble.name = "bubble"
        bubble.size = bubble.texture!.size()
        bubble.anchorPoint = CGPoint(x: 0.5, y: 0)
        bubble.position = CGPoint(x: 0, y: sprite.size.height + 4)
        bubble.zPosition = 9_000
        // Keep the bubble readable at any zoom, and unflipped when the character faces left.
        let scale = min(2.2, max(0.8, zoom))
        bubble.xScale = scale * (sprite.xScale < 0 ? -1 : 1)
        bubble.yScale = scale
        bubble.alpha = 0
        sprite.addChild(bubble)
        sprite.removeAction(forKey: "walk")
        bubble.run(.sequence([.fadeIn(withDuration: 0.2), .wait(forDuration: 4), .fadeOut(withDuration: 0.4), .removeFromParent()]))
    }
}

// MARK: - Ambient life

/// Drifting clouds, the odd flock of birds, and glints on the water. Subtle, and only near the view.
final class AmbientLayer: SKNode {
    private var clouds: [SKSpriteNode] = []
    private var nextBirds: TimeInterval = 6
    private var nextGlint: TimeInterval = 0
    private var glints = 0
    private var elapsed: TimeInterval = 0

    func update(dt: TimeInterval, visible: CGRect, zoom: CGFloat, terrain: TerrainModel?) {
        elapsed += dt
        updateClouds(dt: dt, visible: visible, zoom: zoom)
        if elapsed > nextBirds {
            nextBirds = elapsed + Double.random(in: 14...24)
            spawnBirds(visible: visible, zoom: zoom)
        }
        if let terrain, elapsed > nextGlint, glints < 14 {
            nextGlint = elapsed + 0.22
            spawnGlint(visible: visible, terrain: terrain)
        }
    }

    private func updateClouds(dt: TimeInterval, visible: CGRect, zoom: CGFloat) {
        if clouds.isEmpty {
            for i in 0..<4 {
                let cloud = SKSpriteNode(texture: SpriteArt.cloud)
                cloud.size = SpriteArt.cloud.size()
                cloud.alpha = 0.32
                cloud.zPosition = 8_000
                cloud.position = CGPoint(x: visible.minX + visible.width * CGFloat(i) / 4 + CGFloat.random(in: 0...80),
                                         y: visible.minY + CGFloat.random(in: 0...visible.height))
                addChild(cloud)
                clouds.append(cloud)
            }
        }
        for cloud in clouds {
            cloud.setScale(min(2.5, max(1, zoom * 1.3)))
            cloud.position.x += CGFloat(dt) * 14 * zoom
            cloud.position.y += CGFloat(dt) * 2 * zoom
            if !visible.insetBy(dx: -cloud.size.width, dy: -cloud.size.height).contains(cloud.position) {
                cloud.position = CGPoint(x: visible.minX - cloud.size.width / 2,
                                         y: visible.minY + CGFloat.random(in: 0...visible.height))
            }
        }
    }

    private func spawnBirds(visible: CGRect, zoom: CGFloat) {
        let count = Int.random(in: 3...5)
        let start = CGPoint(x: visible.minX - 40 * zoom, y: visible.minY + visible.height * CGFloat.random(in: 0.3...0.8))
        let end = CGPoint(x: visible.maxX + 40 * zoom, y: start.y + visible.height * CGFloat.random(in: -0.1...0.2))
        let flap = SKAction.repeatForever(.animate(with: [SpriteArt.birdUp, SpriteArt.birdDown], timePerFrame: 0.2))
        for i in 0..<count {
            let bird = SKSpriteNode(texture: SpriteArt.birdUp)
            bird.size = SpriteArt.birdUp.size()
            bird.setScale(min(2.2, max(0.9, zoom)))
            bird.zPosition = 8_500
            let offset = CGPoint(x: -CGFloat(i) * 18 * zoom, y: CGFloat(i % 2 == 0 ? i : -i) * 9 * zoom)
            bird.position = CGPoint(x: start.x + offset.x, y: start.y + offset.y)
            addChild(bird)
            bird.run(flap)
            bird.run(.sequence([.move(to: CGPoint(x: end.x + offset.x, y: end.y + offset.y), duration: 11), .removeFromParent()]))
        }
    }

    private func spawnGlint(visible: CGRect, terrain: TerrainModel) {
        let p = CGPoint(x: CGFloat.random(in: visible.minX...visible.maxX), y: CGFloat.random(in: visible.minY...visible.maxY))
        let g = Iso.grid(p)
        let kind = terrain.kind(Int(g.x), Int(g.y))
        guard kind == .sea || kind == .lake || kind == .river || kind == .ocean else { return }
        let glint = SKSpriteNode(texture: SpriteArt.glint)
        glint.size = SpriteArt.glint.size()
        glint.position = p
        glint.zPosition = 1
        glint.alpha = 0
        glints += 1
        addChild(glint)
        // Count down before removal: actions stop once a node leaves the tree.
        glint.run(.sequence([.fadeAlpha(to: 0.8, duration: 0.8), .fadeOut(withDuration: 0.9),
                             .run { [weak self] in self?.glints -= 1 }, .removeFromParent()]))
    }
}

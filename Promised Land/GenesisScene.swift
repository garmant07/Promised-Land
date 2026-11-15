import SwiftUI

struct SceneLayout: Decodable, Equatable {
    let book: String
    let chapters: Int
    let events: [SceneEvent]

    func events(at stage: Int) -> [SceneEvent] {
        var slots: [String: SceneEvent] = [:]
        for event in events where event.chapter <= max(0, min(stage, chapters)) { slots[event.slot] = event }
        return slots.values.sorted { ($0.u + $0.v, $0.chapter) < ($1.u + $1.v, $1.chapter) }
    }
}

struct SceneEvent: Decodable, Equatable {
    let chapter: Int
    let action: String
    let slot: String
    let sprite: String
    let u: CGFloat
    let v: CGFloat
    let width: CGFloat
    let mirror: Bool
    let tall: Bool

    private enum CodingKeys: String, CodingKey {
        case chapter, action, slot, sprite, u, v, width, mirror, tall
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        chapter = try values.decode(Int.self, forKey: .chapter)
        action = try values.decode(String.self, forKey: .action)
        slot = try values.decode(String.self, forKey: .slot)
        sprite = try values.decode(String.self, forKey: .sprite)
        u = try values.decode(CGFloat.self, forKey: .u)
        v = try values.decode(CGFloat.self, forKey: .v)
        width = try values.decode(CGFloat.self, forKey: .width)
        mirror = try values.decode(Bool.self, forKey: .mirror)
        tall = try values.decodeIfPresent(Bool.self, forKey: .tall) ?? false
    }
}

enum SceneRevealKind: Equatable { case pop, crossfade }
enum SceneLayer { case all, back, tall }

/// Loads an authored scene by book id. Genesis is the first scene, but the loader is not Genesis-specific.
enum SceneLayoutLoader {
    static func load(bookID: String, bundle: Bundle = .main) -> SceneLayout? {
        guard let url = bundle.url(forResource: "\(bookID)_scene", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }

    static func decode(_ data: Data) -> SceneLayout? { try? JSONDecoder().decode(SceneLayout.self, from: data) }
}

/// The Genesis Place is a small authored scene rather than a collection of generic Place pieces.
@MainActor
enum GenesisScene {
    static let bookID = "genesis"
    static let previewStageKey = "debug.genesisStage"
    private static let layout = SceneLayoutLoader.load(bookID: bookID)

    #if DEBUG
    static var previewStage: Int?
    #endif

    static func stage(for item: Island.Item) -> Int {
        return max(0, min(item.progress, 50))
    }

    static var renderGeneration: Int {
        #if DEBUG
        return previewStage ?? -1
        #else
        return -1
        #endif
    }

    static func activeEvents(at stage: Int) -> [SceneEvent] { layout?.events(at: stage) ?? [] }

    static func occludesVillager(_ item: Island.Item) -> Bool {
        guard item.source.bookID == bookID else { return false }
        return activeEvents(at: stage(for: item)).contains(where: \.tall)
    }

    static func revealKind(from: Int, to: Int) -> SceneRevealKind { from == 0 ? .pop : .crossfade }

    /// The scene's complete drawn bounds around the item's ground point, in local points.
    static func localBounds(item: Island.Item, u: CGFloat, stage: Int? = nil) -> CGRect {
        let sceneStage = stage ?? self.stage(for: item)
        let halfWidth = item.span * 22 * u
        let halfHeight = item.span * 11 * u
        let plotWidth = halfWidth * 2
        var result = CGRect.null
        for event in activeEvents(at: sceneStage) {
            guard let art = ArtAssets.image(event.sprite) else { continue }
            let ground = CGPoint(x: (event.u - event.v) * halfWidth,
                                 y: (event.u + event.v - 1) * halfHeight)
            let width = plotWidth * event.width
            let imageScale = width / art.size.width
            let size = CGSize(width: art.size.width * imageScale, height: art.size.height * imageScale)
            let anchor = CGPoint(x: size.width / 2, y: size.height * 300 / 384)
            result = result.union(CGRect(x: ground.x - anchor.x, y: ground.y - anchor.y,
                                         width: size.width, height: size.height))
        }
        return result.isNull ? .zero : result
    }

    /// Draws all events through the current chapter. The item is anchored at the Place centre.
    static func draw(_ context: inout GraphicsContext, item: Island.Item, u: CGFloat, layer: SceneLayer = .all) {
        #if DEBUG
        PerfProbe.genesisDraw()
        #endif
        drawStage(&context, item: item, u: u, stage: self.stage(for: item), layer: layer)
    }

    /// Draws one reveal directly: unchanged slots are final and still, while the changing slot
    /// either pops in or crossfades between the two authored sprites.
    static func drawReveal(_ context: inout GraphicsContext, item: Island.Item, u: CGFloat,
                           from: Int, to: Int, progress: CGFloat) {
        let oldEvents = Dictionary(activeEvents(at: from).map { ($0.slot, $0) }, uniquingKeysWith: { a, _ in a })
        let newEvents = Dictionary(activeEvents(at: to).map { ($0.slot, $0) }, uniquingKeysWith: { a, _ in a })
        let changed = Set(newEvents.keys).union(oldEvents.keys).filter { oldEvents[$0] != newEvents[$0] }
        let t = max(0, min(1, progress))
        let unchanged = newEvents.values.filter { !changed.contains($0.slot) }
        drawEvents(&context, item: item, u: u, events: unchanged)
        for slot in changed.sorted() {
            if let old = oldEvents[slot], let new = newEvents[slot] {
                drawEvents(&context, item: item, u: u, events: [old], opacity: 1 - t)
                drawEvents(&context, item: item, u: u, events: [new], opacity: t)
            } else if let new = newEvents[slot] {
                drawEvents(&context, item: item, u: u, events: [new], opacity: t,
                           scale: t < 1 ? 1 + 0.15 * (1 - t) : 1)
            }
        }
    }

    private static func drawStage(_ context: inout GraphicsContext, item: Island.Item, u: CGFloat, stage: Int, layer: SceneLayer) {
        guard stage > 0 else { return }
        drawEvents(&context, item: item, u: u, events: activeEvents(at: stage), layer: layer)
    }

    private static func drawEvents(_ context: inout GraphicsContext, item: Island.Item, u: CGFloat,
                                   events: [SceneEvent], opacity: CGFloat = 1, scale: CGFloat = 1,
                                   layer: SceneLayer = .all) {
        guard opacity > 0 else { return }
        let halfWidth = item.span * 22 * u
        let halfHeight = item.span * 11 * u
        let plotWidth = halfWidth * 2
        for event in events where layer == .all || (layer == .tall && event.tall) || (layer == .back && !event.tall) {
            guard let art = ArtAssets.image(event.sprite) else { continue }
            let ground = CGPoint(x: (event.u - event.v) * halfWidth,
                                 y: (event.u + event.v - 1) * halfHeight)
            let width = plotWidth * event.width
            let imageScale = width / art.size.width
            let size = CGSize(width: art.size.width * imageScale, height: art.size.height * imageScale)
            let anchor = CGPoint(x: size.width / 2, y: size.height * 300 / 384)
            if event.sprite != "obj_butterflies" {
                let shadow = CGRect(x: ground.x - width * 0.26, y: ground.y - width * 0.07,
                                    width: width * 0.52, height: width * 0.14)
                context.fill(Path(ellipseIn: shadow), with: .color(.black.opacity(0.10)))
            }
            var sprite = context
            sprite.opacity = opacity
            if scale != 1 {
                sprite.translateBy(x: ground.x, y: ground.y)
                sprite.scaleBy(x: scale, y: scale)
                sprite.translateBy(x: -ground.x, y: -ground.y)
            }
            if event.mirror {
                sprite.translateBy(x: ground.x * 2, y: 0)
                sprite.scaleBy(x: -1, y: 1)
            }
            sprite.draw(Image(decorative: art.image, scale: 1),
                        in: CGRect(x: ground.x - anchor.x, y: ground.y - anchor.y,
                                   width: size.width, height: size.height))
        }
    }
}

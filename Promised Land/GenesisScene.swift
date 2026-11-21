import SwiftUI

struct SceneLayout: Decodable, Equatable {
    let book: String
    let chapters: Int
    let events: [SceneEvent]

    var identity: String { "\(book.lowercased())-\(chapters)-\(events.count)" }

    func events(at stage: Int) -> [SceneEvent] {
        var slots: [String: SceneEvent] = [:]
        for event in events where event.chapter <= max(0, min(stage, chapters)) {
            slots[event.slot] = event
        }
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
    let shadowWidth: CGFloat?
    let tall: Bool?

    private enum CodingKeys: String, CodingKey {
        case chapter, action, slot, sprite, u, v, width, mirror, shadowWidth, tall
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
        shadowWidth = try values.decodeIfPresent(CGFloat.self, forKey: .shadowWidth)
        tall = try values.decodeIfPresent(Bool.self, forKey: .tall)
    }
}

enum SceneRevealKind: Equatable { case pop, crossfade }
enum SceneLayer: Equatable { case all, back, tall, front(CGFloat) }

enum SceneLayoutLoader {
    static func load(bookID: String, bundle: Bundle = .main) -> SceneLayout? {
        guard let url = bundle.url(forResource: "\(bookID)_scene", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }

    static func decode(_ data: Data) -> SceneLayout? { try? JSONDecoder().decode(SceneLayout.self, from: data) }
}

@MainActor
enum SceneSystem {
    static let previewBookKey = "debug.sceneBook"
    static let previewStageKey = "debug.sceneStage"
    private static var layouts: [String: SceneLayout?] = [:]
    private static var eventsCache: [String: [SceneEvent]] = [:]
    private static var tallCache: [String: Bool] = [:]

    #if DEBUG
    static var previewBookID: String?
    static var previewStage: Int?
    /// Test-only switch used by the headless renderer benchmark. Release always uses scenes.
    static var scenesEnabled = true
    #endif

    static func layout(for bookID: String) -> SceneLayout? {
        #if DEBUG
        guard scenesEnabled else { return nil }
        #endif
        if let cached = layouts[bookID] { return cached }
        let layout = SceneLayoutLoader.load(bookID: bookID)
        layouts[bookID] = layout
        return layout
    }

    static var bookIDs: [String] {
        BibleCatalog.books.map(\.id).filter { layout(for: $0) != nil }
    }

    static func isSceneBook(_ bookID: String) -> Bool { layout(for: bookID) != nil }

    static func stage(for item: Island.Item) -> Int {
        guard let bookID = item.source.bookID, let layout = layout(for: bookID) else { return 0 }
        #if DEBUG
        if previewBookID == bookID, let previewStage { return max(0, min(previewStage, layout.chapters)) }
        #endif
        return max(0, min(item.progress, layout.chapters))
    }

    static var renderGeneration: Int {
        #if DEBUG
        var hasher = Hasher()
        hasher.combine(previewBookID)
        hasher.combine(previewStage)
        return hasher.finalize()
        #else
        return -1
        #endif
    }

    static func activeEvents(for bookID: String, at stage: Int) -> [SceneEvent] {
        guard let layout = layout(for: bookID) else { return [] }
        let clampedStage = max(0, min(stage, layout.chapters))
        let key = "\(bookID)|\(clampedStage)"
        if let cached = eventsCache[key] { return cached }
        let result = layout.events(at: clampedStage)
        eventsCache[key] = result
        return result
    }

    static func isTall(_ event: SceneEvent, item: Island.Item) -> Bool {
        if let tall = event.tall { return tall }
        let key = "\(event.sprite)|\(event.width)|\(item.span)"
        if let cached = tallCache[key] { return cached }
        guard let art = ArtAssets.image(event.sprite) else { return false }
        #if DEBUG
        PerfProbe.opaqueMeasurement()
        #endif
        let top = OpaqueBounds.unitRect(of: art.image).minY * 384
        let plotWidth = item.span * 44
        let drawnHeight = max(0, (300 - top) / 384) * 1.5 * event.width * plotWidth
        let result = drawnHeight >= 7.5
        tallCache[key] = result
        return result
    }

    static func activeEvents(for item: Island.Item, at stage: Int? = nil) -> [SceneEvent] {
        guard let bookID = item.source.bookID else { return [] }
        return activeEvents(for: bookID, at: stage ?? self.stage(for: item))
    }

    static func occludesVillager(_ item: Island.Item) -> Bool {
        activeEvents(for: item).contains { isTall($0, item: item) }
    }

    static func revealKind(from: Int, to: Int) -> SceneRevealKind { from == 0 ? .pop : .crossfade }

    static func localBounds(item: Island.Item, u: CGFloat, stage: Int? = nil,
                             layer: SceneLayer = .all) -> CGRect {
        let sceneStage = stage ?? self.stage(for: item)
        let halfWidth = item.span * 22 * u
        let halfHeight = item.span * 11 * u
        let plotWidth = halfWidth * 2
        var result = CGRect.null
        for event in activeEvents(for: item, at: sceneStage) {
            let tall = isTall(event, item: item)
            let visible: Bool
            switch layer {
            case .all:
                visible = true
            case .back:
                visible = !tall
            case .tall:
                visible = tall
            case .front(let depth):
                visible = event.u + event.v >= depth
            }
            guard visible else { continue }
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

    static func artRegions(item: Island.Item, u: CGFloat, stage: Int? = nil) -> [HitRegion.Part] {
        let sceneStage = stage ?? self.stage(for: item)
        let halfWidth = item.span * 22 * u
        let halfHeight = item.span * 11 * u
        let plotWidth = halfWidth * 2
        return activeEvents(for: item, at: sceneStage).compactMap { event in
            guard let art = ArtAssets.image(event.sprite) else { return nil }
            let ground = CGPoint(x: (event.u - event.v) * halfWidth,
                                 y: (event.u + event.v - 1) * halfHeight)
            let width = plotWidth * event.width
            let imageScale = width / art.size.width
            let size = CGSize(width: art.size.width * imageScale, height: art.size.height * imageScale)
            let anchor = CGPoint(x: size.width / 2, y: size.height * 300 / 384)
            let x = event.mirror ? ground.x + anchor.x - size.width : ground.x - anchor.x
            let rect = CGRect(x: x, y: ground.y - anchor.y, width: size.width, height: size.height)
            let mask = LandmarkMiniCache.alphaMask(event.sprite, art.image)
            let alpha = event.mirror
                ? stride(from: 0, to: mask.count, by: 64).flatMap { mask[$0..<$0 + 64].reversed() }
                : mask
            return HitRegion.Part(bounds: rect, alpha: alpha)
        }
    }

    static func draw(_ context: inout GraphicsContext, item: Island.Item, u: CGFloat, layer: SceneLayer = .all) {
        #if DEBUG
        PerfProbe.sceneDraw()
        if layer == .tall { PerfProbe.tallLayerRedraw() }
        #endif
        drawStage(&context, item: item, u: u, stage: self.stage(for: item), layer: layer)
    }

    static func drawReveal(_ context: inout GraphicsContext, item: Island.Item, u: CGFloat,
                           from: Int, to: Int, progress: CGFloat) {
        let oldEvents = Dictionary(activeEvents(for: item, at: from).map { ($0.slot, $0) }, uniquingKeysWith: { a, _ in a })
        let newEvents = Dictionary(activeEvents(for: item, at: to).map { ($0.slot, $0) }, uniquingKeysWith: { a, _ in a })
        let changed = Set(newEvents.keys).union(oldEvents.keys).filter { oldEvents[$0] != newEvents[$0] }
        let t = max(0, min(1, progress))
        drawEvents(&context, item: item, u: u, events: newEvents.values.filter { !changed.contains($0.slot) }.map { $0 })
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
        drawEvents(&context, item: item, u: u, events: activeEvents(for: item, at: stage), layer: layer)
    }

    private static func drawEvents(_ context: inout GraphicsContext, item: Island.Item, u: CGFloat,
                                   events: [SceneEvent], opacity: CGFloat = 1, scale: CGFloat = 1,
                                   layer: SceneLayer = .all) {
        guard opacity > 0 else { return }
        let halfWidth = item.span * 22 * u
        let halfHeight = item.span * 11 * u
        let plotWidth = halfWidth * 2
        for event in events.sorted(by: { ($0.u + $0.v, $0.chapter) < ($1.u + $1.v, $1.chapter) }) {
            let tall = isTall(event, item: item)
            let visible: Bool
            switch layer {
            case .all:
                visible = true
            case .back:
                visible = !tall
            case .tall:
                visible = tall
            case .front(let depth):
                visible = event.u + event.v >= depth
            }
            guard visible else { continue }
            guard let art = ArtAssets.image(event.sprite) else { continue }
            let ground = CGPoint(x: (event.u - event.v) * halfWidth,
                                 y: (event.u + event.v - 1) * halfHeight)
            let width = plotWidth * event.width
            let imageScale = width / art.size.width
            let size = CGSize(width: art.size.width * imageScale, height: art.size.height * imageScale)
            let anchor = CGPoint(x: size.width / 2, y: size.height * 300 / 384)
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
            #if DEBUG
            PerfProbe.spriteImageDrawn()
            #endif
            sprite.draw(Image(decorative: art.image, scale: 1),
                        in: CGRect(x: ground.x - anchor.x, y: ground.y - anchor.y,
                                   width: size.width, height: size.height))
        }
    }
}

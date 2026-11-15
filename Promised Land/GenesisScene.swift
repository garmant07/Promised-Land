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
}

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
        #if DEBUG
        if let previewStage { return max(0, min(previewStage, 50)) }
        #endif
        return max(0, min(Int(item.progress.rounded()), 50))
    }

    static func activeEvents(at stage: Int) -> [SceneEvent] { layout?.events(at: stage) ?? [] }

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
            let scale = width / art.size.width
            let size = CGSize(width: art.size.width * scale, height: art.size.height * scale)
            let anchor = CGPoint(x: size.width / 2, y: size.height * 300 / 384)
            result = result.union(CGRect(x: ground.x - anchor.x, y: ground.y - anchor.y,
                                         width: size.width, height: size.height))
        }
        return result.isNull ? .zero : result
    }

    /// Draws all events through the current chapter. The item is anchored at the Place centre.
    static func draw(_ context: inout GraphicsContext, item: Island.Item, u: CGFloat) {
        let stage = self.stage(for: item)
        guard stage > 0 else { return }
        let halfWidth = item.span * 22 * u
        let halfHeight = item.span * 11 * u
        let plotWidth = halfWidth * 2
        for event in activeEvents(at: stage) {
            guard let art = ArtAssets.image(event.sprite) else { continue }
            let ground = CGPoint(x: (event.u - event.v) * halfWidth,
                                 y: (event.u + event.v - 1) * halfHeight)
            let width = plotWidth * event.width
            let scale = width / art.size.width
            let size = CGSize(width: art.size.width * scale, height: art.size.height * scale)
            let anchor = CGPoint(x: size.width / 2, y: size.height * 300 / 384)
            if event.sprite != "obj_butterflies" {
                let shadow = CGRect(x: ground.x - width * 0.26, y: ground.y - width * 0.07,
                                    width: width * 0.52, height: width * 0.14)
                context.fill(Path(ellipseIn: shadow), with: .color(.black.opacity(0.10)))
            }
            var sprite = context
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

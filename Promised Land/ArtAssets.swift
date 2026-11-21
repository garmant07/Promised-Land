import SwiftUI
import UIKit

/// Optional hand-made art. If an image with the right name is in the asset catalogue it's
/// drawn instead of the code-drawn art; otherwise the code-drawn art is used. See ART_ASSETS.md.
///
/// Names:
/// - `bld_<bookID>_<level>`: a book's building. Level 0 = foundations, 1 = built,
///   2–4 = built plus 1–3 extra floors from full rereads.
/// - `art_<kind>_<level>`: a chapter artifact (kind = an `ArtifactKind` raw value, or a
///   story object id such as `art_genesis-ark_3`), level 1–5.
/// - `char_<id>`: a Bible character (used from Phase 5).
/// Each name is a plain image name.
@MainActor
enum ArtAssets {
#if DEBUG
    /// Temporarily makes the optional object sprites fall back to their code drawings.
    static var forceCodeArt = false
#endif
    /// Authoring scale: one island tile is 64pt wide in the image (128px @2x, 192px @3x).
    static let pointsPerTile: CGFloat = 64

    /// Per-sprite tuning applied after the shared code-art scale. Owners can adjust these values
    /// without changing the sprite canvas or its ground anchor.
    static let spriteMultipliers: [String: CGFloat] = [
        "obj_house": 0.5,
        "obj_tree": 0.5
    ]

    /// A loaded image and its size in points.
    struct Art {
        let name: String
        let image: CGImage
        let size: CGSize
        let anchor: CGPoint
    }

    private static var cache: [String: Art?] = [:]

    static func image(_ name: String) -> Art? { lookup(name) }

    static func building(_ bookID: String, level: Int) -> Art? {
        image("bld_\(bookID)_\(level)")
    }

    static func artifact(_ id: String, level: Int) -> Art? {
        image("art_\(id)_\(level)")
    }

    static func character(_ id: String) -> Art? {
        image("char_\(id)")
    }

    private static func lookup(_ name: String) -> Art? {
#if DEBUG
        if forceCodeArt && name.hasPrefix("obj_") { return nil }
#endif
        if let hit = cache[name] { return hit }
        #if DEBUG
        PerfProbe.imageLoadedOrDecoded()
        #endif
        let art = UIImage(named: name).flatMap { ui in
            ui.cgImage.map {
                let anchor = name == "obj_tree" || name == "obj_house"
                    ? CGPoint(x: 0.5, y: 150 / 192)
                    : CGPoint(x: 0.5, y: 1)
                return Art(name: name, image: $0, size: ui.size, anchor: anchor)
            }
        }
        cache[name] = art
        return art
    }

    /// Draws hand-made art at the supplied ground point, respecting its authored anchor.
    static func draw(_ art: Art, in context: inout GraphicsContext, at ground: CGPoint, tileWidth: CGFloat) {
        let scale = tileWidth / pointsPerTile * (spriteMultipliers[art.name] ?? 1)
        let size = CGSize(width: art.size.width * scale, height: art.size.height * scale)
        let anchor = CGPoint(x: art.anchor.x * size.width, y: art.anchor.y * size.height)
        context.draw(Image(decorative: art.image, scale: 1), in: CGRect(
            x: ground.x - anchor.x,
            y: ground.y - anchor.y,
            width: size.width,
            height: size.height
        ))
    }
}

extension ArtAssets {
    /// A Place piece: `place_<bookID>_<piece>_<level>` (level = richness 1–5).
    static func place(_ bookID: String, piece: String, level: Int) -> Art? {
        image("place_\(bookID)_\(piece)_\(level)")
    }
}

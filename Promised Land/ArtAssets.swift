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
    /// Authoring scale: one island tile is 64pt wide in the image (128px @2x, 192px @3x).
    static let pointsPerTile: CGFloat = 64

    /// A loaded image and its size in points.
    struct Art {
        let image: CGImage
        let size: CGSize
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
        if let hit = cache[name] { return hit }
        let art = UIImage(named: name).flatMap { ui in ui.cgImage.map { Art(image: $0, size: ui.size) } }
        cache[name] = art
        return art
    }
}

extension ArtAssets {
    /// A Place piece: `place_<bookID>_<piece>_<level>` (level = richness 1–5).
    static func place(_ bookID: String, piece: String, level: Int) -> Art? {
        image("place_\(bookID)_\(piece)_\(level)")
    }
}

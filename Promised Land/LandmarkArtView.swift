import SwiftUI

/// Landmark artwork for lists and sheets, drawn by the same painter as the world map.
struct LandmarkArtView: View {
    let landmark: Landmark
    let stage: BuildStage
    let level: GrowthLevel
    let size: CGFloat
    /// Chapters read, so the thumbnail shows the same chapter-by-chapter progress as the map.
    var read: Int? = nil

    var body: some View {
        let total = landmark.book?.chapterCount ?? 1
        // Without an exact count, show a typical point within the stage.
        let shownRead = read ?? (stage == .foundations ? max(1, total / 4) : stage == .rising ? (total * 3) / 4 : total)
        let look = LandmarkLook(style: landmark.style, stage: stage, level: level, size: 4,
                                read: shownRead, total: total)
        Group {
            if let image = LandmarkArtCache.image(for: look) {
                Image(decorative: image, scale: LandmarkArtCache.scale)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .background(Color.sand.opacity(stage == .plot ? 0.5 : 0.35),
                    in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Small in-memory cache so list rows don't redraw artwork.
@MainActor
enum LandmarkArtCache {
    static let scale: CGFloat = 1.5
    private static var images: [LandmarkLook: CGImage] = [:]
    private static var order: [LandmarkLook] = []

    static func image(for look: LandmarkLook) -> CGImage? {
        if let cached = images[look] { return cached }
        guard let rendered = LandmarkPainter.render(look, scale: scale)?.image else { return nil }
        images[look] = rendered
        order.append(look)
        if order.count > 60 { images[order.removeFirst()] = nil }
        return rendered
    }
}

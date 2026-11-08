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
        LandmarkThumbnail(look: look)
        .frame(width: size, height: size)
        .background(Color.sand.opacity(stage == .plot ? 0.5 : 0.35),
                    in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// The artwork itself: shown at once if it's cached, otherwise drawn off the main thread and
/// faded in, so scrolling a list never waits for a painter.
private struct LandmarkThumbnail: View {
    let look: LandmarkLook
    @State private var drawn: (look: LandmarkLook, image: CGImage)?

    var body: some View {
        let image = LandmarkArtCache.cached(look) ?? (drawn?.look == look ? drawn?.image : nil)
        Group {
            if let image {
                Image(decorative: image, scale: LandmarkArtCache.scale)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .task(id: look) {
            guard LandmarkArtCache.cached(look) == nil else { return }
            if let image = await LandmarkArtCache.render(look) {
                withAnimation(.easeOut(duration: 0.15)) { drawn = (look, image) }
            }
        }
    }
}

/// In-memory cache so list rows don't redraw artwork. Big enough for every book at a couple of
/// stages, so scrolling back up never redraws.
@MainActor
enum LandmarkArtCache {
    static let scale: CGFloat = 1.5
    private static let limit = 240
    private static var images: [LandmarkLook: CGImage] = [:]
    private static var order: [LandmarkLook] = []

    static func cached(_ look: LandmarkLook) -> CGImage? { images[look] }

    /// Draws in the background and caches the result.
    static func render(_ look: LandmarkLook) async -> CGImage? {
        if let cached = images[look] { return cached }
        let scale = scale
        let rendered = await Task.detached(priority: .userInitiated) {
            LandmarkPainter.render(look, scale: scale)?.image
        }.value
        if let rendered { store(rendered, for: look) }
        return rendered
    }

    private static func store(_ image: CGImage, for look: LandmarkLook) {
        guard images[look] == nil else { return }
        images[look] = image
        order.append(look)
        if order.count > limit { images[order.removeFirst()] = nil }
    }
}

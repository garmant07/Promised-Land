import SwiftUI

/// Landmark artwork for lists and sheets, drawn by the same painter as the world map.
struct LandmarkArtView: View {
    let landmark: Landmark
    let stage: BuildStage
    let level: GrowthLevel
    let size: CGFloat

    var body: some View {
        let look = LandmarkLook(style: landmark.style, stage: stage, level: level, size: 4)
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

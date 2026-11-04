import SwiftUI

/// Small artwork for a landmark, used in lists and sheets.
/// (Phase 1 placeholder: replaced by the world's own drawn textures in Phase 3.)
struct LandmarkArtView: View {
    let landmark: Landmark
    let stage: BuildStage
    let level: GrowthLevel
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(stage == .plot ? Color.sand : Color.stoneLight)
            .overlay {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(stage == .plot ? Color.secondaryText.opacity(0.4) : Color.terracotta)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

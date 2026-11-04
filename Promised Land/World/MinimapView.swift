import SwiftUI
import Observation

/// The camera's visible area, published by the scene a few times a second.
@Observable
final class MinimapModel {
    var viewport: CGRect = .zero
}

/// A small overview of every region (fogged or clear), landmarks, and the current view.
struct MinimapView: View {
    let progress: GameProgress
    let model: MinimapModel
    var jump: (CGPoint) -> Void

    private static let bounds = Iso.sceneBounds(width: WorldData.mapWidth, height: WorldData.mapHeight)
    static let width: CGFloat = 168
    static var height: CGFloat { width * bounds.height / bounds.width }

    var body: some View {
        Canvas { context, size in
            let k = size.width / Self.bounds.width
            func point(_ grid: CGPoint) -> CGPoint {
                let s = Iso.scene(grid)
                return CGPoint(x: (s.x - Self.bounds.minX) * k, y: (Self.bounds.maxY - s.y) * k)
            }
            func polygon(_ grid: [CGPoint]) -> Path {
                Path { p in p.addLines(grid.map(point)); p.closeSubpath() }
            }
            func rect(_ r: GridRect) -> Path {
                polygon([CGPoint(x: r.x, y: r.y), CGPoint(x: r.x + r.w, y: r.y),
                         CGPoint(x: r.x + r.w, y: r.y + r.h), CGPoint(x: r.x, y: r.y + r.h)])
            }
            func ellipse(_ e: Ellipse) -> Path {
                polygon((0..<20).map { i in
                    let a = Double(i) / 20 * 2 * .pi
                    return CGPoint(x: e.cx + cos(a) * e.rx, y: e.cy + sin(a) * e.ry)
                })
            }

            let W = Double(WorldData.mapWidth), H = Double(WorldData.mapHeight)
            context.fill(polygon([CGPoint(x: 1.5, y: 1.5), CGPoint(x: W - 1.5, y: 1.5),
                                  CGPoint(x: W - 1.5, y: H - 1.5), CGPoint(x: 1.5, y: H - 1.5)]), with: .color(.sand))
            for region in WorldData.regions {
                let revealed = progress.isRegionRevealed(region.id)
                context.fill(rect(region.bounds), with: .color(revealed ? Color(hex: region.ground) : Color.card))
            }
            context.fill(polygon(WorldData.mediterranean), with: .color(.water))
            context.fill(ellipse(WorldData.patmos), with: .color(progress.isRegionRevealed("patmos") ? Color(hex: "#EFE6CC") : .card))
            context.fill(ellipse(WorldData.seaOfGalilee), with: .color(.water))
            context.fill(ellipse(WorldData.deadSea), with: .color(.water))

            for landmark in WorldData.landmarks {
                let stage = progress.stage(of: landmark.bookID)
                guard stage > .plot else { continue }
                let p = point(landmark.center)
                let r: CGFloat = stage == .complete ? 2.6 : 1.8
                context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                             with: .color(stage == .complete ? .olive : .terracotta))
            }

            let v = model.viewport
            if v.width > 0 {
                let frame = CGRect(x: (v.minX - Self.bounds.minX) * k, y: (Self.bounds.maxY - v.maxY) * k,
                                   width: v.width * k, height: v.height * k)
                context.stroke(Path(roundedRect: frame, cornerRadius: 3), with: .color(.primaryBrown), lineWidth: 1.5)
            }
        }
        .frame(width: Self.width, height: Self.height)
        .padding(8)
        .background(Color.water.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.clear))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .gesture(SpatialTapGesture().onEnded { value in
            let k = Self.width / Self.bounds.width
            let local = CGPoint(x: value.location.x - 8, y: value.location.y - 8)
            jump(CGPoint(x: local.x / k + Self.bounds.minX, y: Self.bounds.maxY - local.y / k))
        })
        .accessibilityElement()
        .accessibilityLabel("Minimap")
        .accessibilityHint("Tap a spot to move the map there.")
        .accessibilityAddTraits(.isButton)
    }
}

/// Explains a cross-reference road when it is tapped.
struct ConnectionCard: View {
    let connection: Connection
    var close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Connection", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.terracotta)
                    Text(connection.title)
                        .font(.serifTitle(.title3))
                        .foregroundStyle(Color.bodyText)
                }
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.secondaryText)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
            }
            Text("\(BibleCatalog.book(id: connection.a)?.name ?? "") ↔ \(BibleCatalog.book(id: connection.b)?.name ?? "")")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primaryBrown)
            Text(connection.text)
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.primaryBrown.opacity(0.12), radius: 12, y: 4)
    }
}

#Preview {
    VStack {
        MinimapView(progress: .empty, model: MinimapModel()) { _ in }
        ConnectionCard(connection: WorldData.connections[0]) {}
    }
    .padding()
    .background(Color.cream)
}

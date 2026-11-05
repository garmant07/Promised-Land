#if DEBUG
import SwiftUI
import QuartzCore

/// DEBUG: frames per second, measured with a display link (Settings → Developer → FPS overlay),
/// and how many things the island drew in the last frame (its "node count": the island is a
/// `Canvas`, so this counts images, items and figures drawn; see `RenderStats`).
struct FPSMeter: View {
    @State private var counter = FrameCounter()

    var body: some View {
        Text("\(counter.fps) fps · \(counter.draws) draws")
            .font(.caption.monospacedDigit().weight(.bold))
            .foregroundStyle(counter.fps >= 55 ? Color.olive : counter.fps >= 40 ? Color.wheat : Color.terracotta)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.cream.opacity(0.9), in: Capsule())
            .onAppear { counter.start() }
            .onDisappear { counter.stop() }
            .accessibilityHidden(true)
    }
}

@MainActor @Observable
final class FrameCounter {
    private(set) var fps = 0
    private(set) var draws = 0
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var frames = 0
    @ObservationIgnored private var since = CACurrentMediaTime()

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() { link?.invalidate(); link = nil }

    @objc private func tick() {
        frames += 1
        let now = CACurrentMediaTime()
        if now - since >= 0.5 {
            fps = Int((Double(frames) / (now - since)).rounded())
            draws = RenderStats.total
            frames = 0
            since = now
        }
    }
}
#endif

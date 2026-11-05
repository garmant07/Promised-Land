import SwiftUI
import QuartzCore

/// Times named pieces of the island's main-thread work (DEBUG only; a plain call in Release).
/// Read by the FPS overlay and by the `-perfLog` console log.
@MainActor
enum PerfProbe {
    #if DEBUG
    /// Seconds spent in each section, and how many times it ran, since the last report.
    static var totals: [String: (time: Double, calls: Int)] = [:]
    static let logging = ProcessInfo.processInfo.arguments.contains("-perfLog")
    #endif

    @inline(__always)
    static func measure<T>(_ label: StaticString, _ body: () throws -> T) rethrows -> T {
        #if DEBUG
        let start = CACurrentMediaTime()
        defer {
            let key = "\(label)"
            let old = totals[key] ?? (0, 0)
            totals[key] = (old.time + CACurrentMediaTime() - start, old.calls + 1)
        }
        #endif
        return try body()
    }
}

#if DEBUG
/// DEBUG: frames per second, measured with a display link (Settings → Developer → FPS overlay).
/// The island is a SwiftUI `Canvas`, not SpriteKit, so the SpriteKit counters map like this:
/// - **nodes**: everything the island holds (items, villagers, travellers, Bible characters);
///   what SpriteKit would keep as nodes. Only what's on screen is ever looked at.
/// - **draws**: images, items and figures drawn in the last frame (`RenderStats`).
/// - **ms**: main-thread time per frame spent planning and drawing the island.
struct FPSMeter: View {
    @State private var counter = FrameCounter()

    var body: some View {
        Text("\(counter.fps) fps · \(counter.nodes) nodes · \(counter.draws) draws · \(counter.ms, format: .number.precision(.fractionLength(1))) ms")
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
    private(set) var nodes = 0
    private(set) var ms: Double = 0
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var frames = 0
    @ObservationIgnored private var since = CACurrentMediaTime()
    /// With `-perfLog`, one counter runs for the whole session and prints once a second.
    @ObservationIgnored private let logs: Bool

    init(logs: Bool = false) { self.logs = logs }

    static let logger = FrameCounter(logs: true)

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
        let window = logs ? 1.0 : 0.5
        guard now - since >= window else { return }
        let elapsed = now - since
        fps = Int((Double(frames) / elapsed).rounded())
        draws = RenderStats.total
        nodes = RenderStats.nodes
        let island = PerfProbe.totals.values.reduce(0) { $0 + $1.time }
        ms = frames > 0 ? island / Double(frames) * 1000 : 0
        if logs {
            let parts = PerfProbe.totals.sorted { $0.key < $1.key }.map { key, v in
                String(format: "%@ %.2fms×%d", key, v.time / Double(frames) * 1000, v.calls)
            }
            print(String(format: "PERF fps=%d nodes=%d draws=%d ms/frame=%.2f | ", fps, nodes, draws, ms) + parts.joined(separator: " | "))
        }
        // Only the logger empties the totals, so the overlay reads the same numbers it does.
        if logs || !PerfProbe.logging { PerfProbe.totals = [:] }
        frames = 0
        since = now
    }
}
#endif

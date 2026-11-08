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
    /// The longest gap between two frames in this window (a hitch shows here, not in the average).
    @ObservationIgnored private var lastFrame = CACurrentMediaTime()
    @ObservationIgnored private var worst: Double = 0
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
        worst = max(worst, now - lastFrame)
        lastFrame = now
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
            print(String(format: "PERF fps=%d worst=%.1fms nodes=%d draws=%d ms/frame=%.2f | ", fps, worst * 1000, nodes, draws, ms)
                  + parts.joined(separator: " | "))
        }
        // Only the logger empties the totals, so the overlay reads the same numbers it does.
        if logs || !PerfProbe.logging { PerfProbe.totals = [:] }
        frames = 0
        worst = 0
        since = now
    }
}
#endif

#if DEBUG
/// DEBUG: how long a screen takes to open, from the moment it's asked for to its first frame.
/// Prints "OPEN <name>: n ms" to the console (used with the `-open…` launch options).
@MainActor
enum OpenTiming {
    private static var started: [String: CFTimeInterval] = [:]

    static func begin(_ name: String) { started[name] = CACurrentMediaTime() }

    /// Called when the screen appears; reports once its first frame has gone out.
    static func end(_ name: String) {
        guard let start = started.removeValue(forKey: name) else { return }
        DispatchQueue.main.async {
            print(String(format: "OPEN %@: %.0f ms", name, (CACurrentMediaTime() - start) * 1000))
        }
    }

    /// The `-openDelay <seconds>` launch option: wait this long after launch before opening
    /// anything, so the timing isn't mixed up with launch.
    static var launchDelay: Double {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-openDelay"), i + 1 < args.count else { return 0 }
        return Double(args[i + 1]) ?? 0
    }

    /// The value after a launch option, if given.
    static func argument(_ flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}
#endif

extension View {
    /// DEBUG: ends an `OpenTiming` measurement when this screen appears. No effect in Release.
    func debugOpenTiming(_ name: String) -> some View {
        #if DEBUG
        onAppear { OpenTiming.end(name) }
        #else
        self
        #endif
    }
}

extension View {
    /// DEBUG: "-openBook psalms" takes that book down from the shelf a second after this screen
    /// appears (as if tapped), timing it as "OPEN Book". No effect in Release.
    func debugOpenBook(_ path: Binding<NavigationPath>) -> some View {
        #if DEBUG
        onAppear {
            guard let id = OpenTiming.argument("-openBook"), let book = BibleCatalog.book(id: id) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                OpenTiming.begin("Book")
                path.wrappedValue.append(book)
            }
        }
        #else
        self
        #endif
    }
}

extension View {
    /// DEBUG: "-autoScroll" scrolls this list to `target` and back over a few seconds, to measure
    /// scrolling with `-perfLog`. No effect in Release.
    func debugAutoScroll<ID: Hashable>(_ proxy: ScrollViewProxy, to target: ID?) -> some View {
        #if DEBUG
        onAppear {
            guard ProcessInfo.processInfo.arguments.contains("-autoScroll"), let target else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                print("SCROLL start")
                withAnimation(.linear(duration: 3)) { proxy.scrollTo(target, anchor: .bottom) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.linear(duration: 3)) { proxy.scrollTo("top", anchor: .top) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { print("SCROLL end") }
                }
            }
        }
        #else
        self
        #endif
    }
}

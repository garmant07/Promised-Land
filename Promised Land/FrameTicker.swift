import QuartzCore

/// Waits for the next screen refresh (a display link): for one-off waits like "after the next frame
/// is on screen" or pacing background work between frames. Not for driving per-frame state
/// changes: those measured slower than a short sleep (an extra SwiftUI update each frame).
@MainActor
final class FrameTicker {
    static let shared = FrameTicker()

    private var link: CADisplayLink?
    private var waiting: [CheckedContinuation<Void, Never>] = []

    /// Resumes at the next frame.
    func nextFrame() async {
        await withCheckedContinuation { continuation in
            waiting.append(continuation)
            if link == nil {
                let link = CADisplayLink(target: self, selector: #selector(tick))
                link.add(to: .main, forMode: .common)
                self.link = link
            }
        }
    }

    @objc private func tick() {
        let ready = waiting
        waiting = []
        // Nobody waiting: stop, so an idle island costs nothing.
        if ready.isEmpty { link?.invalidate(); link = nil }
        for c in ready { c.resume() }
    }
}

/// Quarter turns asked for while one is animating: at most one waits its turn; more taps are ignored.
struct TurnQueue {
    private(set) var turning = false
    private(set) var pending: Int?

    /// A turn was asked for: the step to start now, or nil if one is animating (then it's queued, if
    /// nothing is queued yet).
    mutating func request(_ step: Int) -> Int? {
        guard turning else { turning = true; return step }
        if pending == nil { pending = step }
        return nil
    }

    /// The animation finished: the queued step to start next (still turning), or nil (done).
    mutating func finished() -> Int? {
        if let next = pending { pending = nil; return next }
        turning = false
        return nil
    }
}

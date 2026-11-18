import SwiftUI
import UIKit

enum ChapterReadTimings {
    static let holdDuration = 1.5
    static let floodDuration = 0.45
    static let coverHoldDuration = 1.0
    static let coverFadeDuration = 0.35
}

struct HoldToFinishButtonBoundsKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// The small state machine behind the hold-to-finish gesture.
struct HoldToFinishState: Equatable {
    private(set) var isHolding = false
    private(set) var didComplete = false

    mutating func begin(readingTimerEnabled: Bool, canFinish: Bool) -> Bool {
        guard !readingTimerEnabled || canFinish, !didComplete else { return false }
        isHolding = true
        return true
    }

    mutating func complete() -> Bool {
        guard isHolding, !didComplete else { return false }
        isHolding = false
        didComplete = true
        return true
    }

    mutating func releaseEarly() {
        guard !didComplete else { return }
        isHolding = false
    }
}

/// A press-and-hold confirmation for finishing the chapter.
struct HoldToFinishButton: View {
    static let holdDuration = ChapterReadTimings.holdDuration

    let canFinish: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var holdState = HoldToFinishState()
    @State private var fillProgress = 0.0
    @State private var fillOpacity = 1.0
    @State private var hapticEvent = HapticEvent.none

    private enum HapticEvent: Equatable {
        case none
        case started
        case completed
    }

    private var isEnabled: Bool {
        !ReadingGate.readingTimerEnabled || canFinish
    }

    var body: some View {
        Text("Hold · I read this.")
            .primaryButtonAppearance(background: .card, foreground: .bodyText)
        .overlay {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Color.primaryBrown
                        .frame(width: proxy.size.width * fillProgress)
                        .opacity(fillOpacity)

                    Text("Hold · I read this.")
                        .font(.headline)
                        .foregroundStyle(Color.cream)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .padding(.horizontal, 16)
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: proxy.size.width * fillProgress)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .allowsHitTesting(false)
        }
        .opacity(isEnabled ? 1 : 0.55)
        .anchorPreference(key: HoldToFinishButtonBoundsKey.self, value: .bounds) { $0 }
        .onLongPressGesture(
            minimumDuration: Self.holdDuration,
            maximumDistance: 20,
            perform: complete
        ) { pressing in
            updatePressing(pressing)
        }
        .accessibilityLabel("I read this")
        .accessibilityHint("Press and hold to finish the chapter")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            completeImmediately()
        }
        .sensoryFeedback(trigger: hapticEvent) { _, newValue in
            switch newValue {
            case .started:
                .impact(weight: .light)
            case .completed:
                .impact(weight: .heavy)
            case .none:
                nil
            }
        }
    }

    private func updatePressing(_ pressing: Bool) {
        guard isEnabled else { return }

        if pressing {
            guard holdState.begin(
                readingTimerEnabled: ReadingGate.readingTimerEnabled,
                canFinish: canFinish
            ) else { return }

            hapticEvent = .started
            if reduceMotion {
                fillProgress = 1
                fillOpacity = 0
                withAnimation(.easeIn(duration: Self.holdDuration)) {
                    fillOpacity = 1
                }
            } else {
                withAnimation(.linear(duration: Self.holdDuration)) {
                    fillProgress = 1
                    fillOpacity = 1
                }
            }
        } else if holdState.isHolding {
            holdState.releaseEarly()
            hapticEvent = .none
            if reduceMotion {
                fillProgress = 0
                fillOpacity = 1
            } else {
                withAnimation(.easeOut(duration: 0.25)) {
                    fillProgress = 0
                    fillOpacity = 1
                }
            }
        }
    }

    private func complete() {
        guard holdState.complete() else { return }
        hapticEvent = .completed
        action()
    }

    private func completeImmediately() {
        guard isEnabled else { return }
        guard holdState.begin(
            readingTimerEnabled: ReadingGate.readingTimerEnabled,
            canFinish: canFinish
        ) else { return }
        fillProgress = 1
        fillOpacity = 1
        complete()
    }
}

/// The brown chapter-complete moment shown over the reader before the question sheet opens.
struct ChapterReadCover: View {
    let bookName: String
    let chapter: Int
    let center: CGPoint
    let startsWithFlood: Bool
    @Binding var isVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var circleScale = 0.001
    @State private var isFull = false
    @State private var coverOpacity = 1.0
    @State private var hasStarted = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if startsWithFlood && !reduceMotion {
                    Circle()
                        .fill(Color.primaryBrown)
                        .frame(
                            width: max(1, hypot(proxy.size.width, proxy.size.height)) * 2,
                            height: max(1, hypot(proxy.size.width, proxy.size.height)) * 2
                        )
                        .scaleEffect(circleScale)
                        .position(center)
                } else {
                    Color.primaryBrown
                }

                VStack(spacing: 12) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .semibold))
                    Text("\(bookName) \(chapter) read")
                        .font(.serifTitle(.title2))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Color.cream)
                .opacity(isFull ? 1 : 0)
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isVisible ? coverOpacity : 0)
            .animation(.easeOut(duration: ChapterReadTimings.coverFadeDuration), value: isVisible)
            .allowsHitTesting(isVisible)
            .onAppear {
                startPresentationIfNeeded()
            }
            .onChange(of: isVisible) { _, visible in
                if visible {
                    startPresentationIfNeeded()
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bookName) \(chapter) read")
    }

    private func startPresentationIfNeeded() {
        guard isVisible, !hasStarted else { return }
        hasStarted = true

        if startsWithFlood && !reduceMotion {
            withAnimation(.easeIn(duration: ChapterReadTimings.floodDuration)) {
                circleScale = 1
            }
            Task {
                try? await Task.sleep(for: .seconds(ChapterReadTimings.floodDuration))
                isFull = true
            }
        } else if reduceMotion {
            coverOpacity = 0
            withAnimation(.easeIn(duration: 0.2)) {
                coverOpacity = 1
                isFull = true
            }
        } else {
            isFull = true
        }
    }
}

#Preview("Hold to finish") {
    HoldToFinishButton(canFinish: true, action: {})
        .padding()
        .themedScreen()
}

#Preview("Chapter read cover") {
    ChapterReadCover(
        bookName: "Genesis",
        chapter: 1,
        center: CGPoint(x: 195, y: 300),
        startsWithFlood: false,
        isVisible: .constant(true)
    )
}

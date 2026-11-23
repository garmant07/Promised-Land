import SwiftUI

struct FirstJourneyBubble: View {
    let text: String
    var buttonTitle: String?
    var onButton: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text)
                .font(.body)
                .foregroundStyle(Color.bodyText)
                .fixedSize(horizontal: false, vertical: true)
            if let buttonTitle, let onButton {
                Button(buttonTitle, action: onButton)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(18)
        .frame(maxWidth: 360, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primaryBrown.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.primaryBrown.opacity(0.18), radius: 18, y: 7)
        .accessibilityElement(children: .contain)
    }
}

struct FirstJourneySpotlight: View {
    let libraryBounds: CGRect

    var body: some View {
        GeometryReader { geometry in
            let margin: CGFloat = 28
            let radius = max(libraryBounds.width, libraryBounds.height) / 2 + margin
            let diameter = radius * 2
            let centre = CGPoint(x: libraryBounds.midX, y: libraryBounds.midY)

            ZStack {
                Color.black.opacity(0.58)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.black, .black.opacity(0.82), .clear],
                            center: .center,
                            startRadius: radius * 0.58,
                            endRadius: radius
                        )
                    )
                    .frame(width: diameter, height: diameter)
                    .position(centre)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct FirstPlaceBanner: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Your first Place")
                .font(.serifTitle(.title2))
                .foregroundStyle(Color.bodyText)
            Text("The tree by the water")
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
            Button("Got it", action: onDismiss)
                .buttonStyle(SoftButtonStyle())
                .frame(maxWidth: 220)
        }
        .padding(18)
        .frame(maxWidth: 340)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.primaryBrown.opacity(0.2), radius: 20, y: 8)
        .accessibilityElement(children: .contain)
    }
}

struct FirstJourneyOverlay: View {
    let step: FirstJourneyStep
    let libraryBounds: CGRect
    var onWelcome: () -> Void
    var onExplore: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if step == .library, !libraryBounds.isEmpty {
                    let radius = max(libraryBounds.width, libraryBounds.height) / 2 + 28
                    FirstJourneySpotlight(libraryBounds: libraryBounds)
                        .transition(.opacity)
                    FirstJourneyBubble(text: "This is your Library. Tap it to open your first chapter.")
                        .position(
                            x: libraryBounds.midX,
                            y: min(geometry.size.height - 90, libraryBounds.maxY + radius + 54)
                        )
                        .allowsHitTesting(false)
                        .transition(.opacity)
                } else if step == .welcome {
                    FirstJourneyBubble(
                        text: "Welcome to your island. It starts small, and it grows every time you read.",
                        buttonTitle: "Let's begin",
                        onButton: onWelcome
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 132)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                } else if step == .done {
                    EmptyView()
                } else if step != .library {
                    FirstJourneyBubble(
                        text: "Every chapter you read grows your island. Explore whenever you're ready.",
                        buttonTitle: "Start exploring",
                        onButton: onExplore
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 132)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .opacity(step == .library && libraryBounds.isEmpty ? 0 : 1)
            .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.4), value: libraryBounds.isEmpty)
        }
    }
}

#Preview("Bubble") {
    ZStack {
        Color.blue
        FirstJourneyBubble(text: "Welcome to your island.", buttonTitle: "Let's begin", onButton: {})
            .padding()
    }
}

#Preview("Banner") {
    ZStack {
        Color.blue
        FirstPlaceBanner(onDismiss: {})
    }
}

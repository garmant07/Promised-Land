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

struct FirstJourneySpotlight: Shape {
    var hole: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        if !hole.isEmpty {
            path.addPath(Path(roundedRect: hole.insetBy(dx: -10, dy: -10),
                              cornerSize: CGSize(width: 18, height: 18)))
        }
        return path
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

    var body: some View {
        ZStack {
            if step == .library {
                FirstJourneySpotlight(hole: libraryBounds)
                    .fill(Color.black.opacity(0.58), style: FillStyle(eoFill: true))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                FirstJourneyBubble(text: "This is your Library. Tap it to open your first chapter.")
                    .padding(.horizontal, 20)
                    .padding(.top, 88)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
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
            } else {
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

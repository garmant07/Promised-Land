import SwiftUI

// MARK: - Palette

extension Color {
    /// Creates a colour from a hex string such as "#FAF0DE" or "FAF0DE".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        switch cleaned.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    static let cream = Color(hex: "#FAF0DE")
    static let card = Color(hex: "#F5E8D0")
    static let sand = Color(hex: "#F3DFB5")
    static let stoneLight = Color(hex: "#F4D6AA")
    static let stoneShade = Color(hex: "#E8C192")
    static let terracotta = Color(hex: "#E39A7E")
    static let lavender = Color(hex: "#BFA9DA")
    static let olive = Color(hex: "#A9B47C")
    static let primaryBrown = Color(hex: "#7A4A2A")
    static let onPrimary = Color(hex: "#FAF0DE")
    static let bodyText = Color(hex: "#2F2418")
    static let secondaryText = Color(hex: "#6A5640")

    // Two small supporting tones used only in the world illustrations.
    static let water = Color(hex: "#A9CDD3")
    static let wheat = Color(hex: "#E9C77F")
}

// MARK: - Typography

extension Font {
    static func serifTitle(_ style: Font.TextStyle = .title) -> Font {
        .system(style, design: .serif).weight(.semibold)
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.onPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .background(Color.primaryBrown.opacity(isEnabled ? 1 : 0.4),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.primaryBrown)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .background(Color.sand, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Card

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardBackground()) }

    /// Root tab screens draw their own serif header instead of a navigation bar.
    func hiddenNavigationBar() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    /// Cream page background and matching navigation bar.
    func themedScreen() -> some View {
        #if os(iOS)
        self
            .background(Color.cream.ignoresSafeArea())
            .toolbarBackground(Color.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        #else
        self.background(Color.cream.ignoresSafeArea())
        #endif
    }
}

import SwiftUI

// MARK: - Model

/// The player's own character. Stored as plain UserDefaults values (see `AvatarStorage`).
struct Avatar: Equatable {
    enum Hair: String, CaseIterable, Identifiable {
        case headcloth, short, long, curly
        var id: String { rawValue }
        var title: String {
            switch self {
            case .headcloth: "Headcloth"
            case .short: "Short"
            case .long: "Long"
            case .curly: "Curly"
            }
        }
    }

    var name: String
    var robe: String
    var skin: String
    var hair: Hair
    var hairColor: String

    static let robes = ["#E39A7E", "#BFA9DA", "#A9B47C", "#93AECF", "#E9C77F", "#C98F6E", "#F2EBDD", "#7A4A2A"]
    static let skins = ["#F6D9C0", "#EBC3A0", "#D9A57E", "#B98159", "#8E5E3D", "#5E3D28"]
    static let hairColors = ["#FAF0DE", "#E8C192", "#B48A6A", "#8A5A3C", "#4A3326", "#2F2418", "#A9A29A"]
}

/// AppStorage keys for the avatar, shared by the home page and the customiser.
enum AvatarKeys {
    static let name = "avatarName"
    static let robe = "avatarRobe"
    static let skin = "avatarSkin"
    static let hair = "avatarHair"
    static let hairColor = "avatarHairColor"
}

/// Reads and writes the avatar through @AppStorage so every view stays in sync.
struct AvatarStorage: DynamicProperty {
    @AppStorage(AvatarKeys.name) var name = ""
    @AppStorage(AvatarKeys.robe) var robe = Avatar.robes[0]
    @AppStorage(AvatarKeys.skin) var skin = Avatar.skins[1]
    @AppStorage(AvatarKeys.hair) var hair = Avatar.Hair.headcloth.rawValue
    @AppStorage(AvatarKeys.hairColor) var hairColor = Avatar.hairColors[0]

    var avatar: Avatar {
        Avatar(name: name, robe: robe, skin: skin, hair: Avatar.Hair(rawValue: hair) ?? .headcloth, hairColor: hairColor)
    }
}

// MARK: - Figure

/// A small robed figure, drawn with soft shapes and no outlines.
/// Drawn in a 20 × 36 unit box (y down), scaled to the frame.
struct AvatarFigure: View {
    let avatar: Avatar

    var body: some View {
        Canvas { context, size in
            let s = min(size.width / 20, size.height / 36)
            context.translateBy(x: (size.width - 20 * s) / 2, y: (size.height - 36 * s) / 2)
            context.scaleBy(x: s, y: s)

            let robe = Color(hex: avatar.robe)
            let skin = Color(hex: avatar.skin)
            let hair = Color(hex: avatar.hairColor)

            func ellipse(_ r: CGRect, _ c: Color) { context.fill(Path(ellipseIn: r), with: .color(c)) }
            func rounded(_ r: CGRect, _ radius: CGFloat, _ c: Color) {
                context.fill(Path(roundedRect: r, cornerRadius: radius), with: .color(c))
            }

            // Shadow
            ellipse(CGRect(x: 3, y: 32.2, width: 14, height: 3.6), Color.primaryBrown.opacity(0.12))

            // Long hair falls behind the shoulders
            if avatar.hair == .long { rounded(CGRect(x: 4.4, y: 5, width: 11.2, height: 12), 4, hair) }

            // Robe, with the right side in shade
            let body = Path { p in
                p.move(to: CGPoint(x: 10, y: 11))
                p.addCurve(to: CGPoint(x: 17, y: 33), control1: CGPoint(x: 15, y: 13), control2: CGPoint(x: 17, y: 25))
                p.addLine(to: CGPoint(x: 3, y: 33))
                p.addCurve(to: CGPoint(x: 10, y: 11), control1: CGPoint(x: 3, y: 25), control2: CGPoint(x: 5, y: 13))
            }
            context.fill(body, with: .color(robe))
            var shaded = context
            shaded.clip(to: body)
            shaded.fill(Path(CGRect(x: 10, y: 10, width: 10, height: 24)), with: .color(Color.primaryBrown.opacity(0.10)))
            rounded(CGRect(x: 5.4, y: 19.4, width: 9.2, height: 2.2), 1, Color.cream.opacity(0.75))

            // Headcloth drapes over the shoulders
            if avatar.hair == .headcloth {
                rounded(CGRect(x: 4.2, y: 5, width: 11.6, height: 9.5), 4, hair)
                rounded(CGRect(x: 4.2, y: 5, width: 11.6, height: 9.5), 4, Color.primaryBrown.opacity(0.08))
            }

            // Head and face
            ellipse(CGRect(x: 5.5, y: 3, width: 9, height: 9), skin)
            ellipse(CGRect(x: 7.7, y: 7.0, width: 0.9, height: 0.9), Color.bodyText.opacity(0.65))
            ellipse(CGRect(x: 11.4, y: 7.0, width: 0.9, height: 0.9), Color.bodyText.opacity(0.65))

            // Hair / covering on top
            switch avatar.hair {
            case .headcloth:
                ellipse(CGRect(x: 4.4, y: 1.6, width: 11.2, height: 5.6), hair)
                rounded(CGRect(x: 5, y: 5.2, width: 10, height: 1.2), 0.6, Color.terracotta.opacity(0.55))
            case .short:
                ellipse(CGRect(x: 5.2, y: 2.4, width: 9.6, height: 5), hair)
            case .long:
                ellipse(CGRect(x: 5, y: 2.2, width: 10, height: 5.4), hair)
            case .curly:
                for (x, y) in [(5.6, 4.6), (7.2, 2.8), (9.3, 2.1), (11.4, 2.6), (13.2, 4.4)] {
                    ellipse(CGRect(x: x - 1.6, y: y - 1.6, width: 3.6, height: 3.6), hair)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A single isometric plot of grass, with soft earth sides.
struct GrassPlot: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, depth = size.height * 0.16
            let h = (size.height - depth)
            let top = CGPoint(x: w / 2, y: 0), right = CGPoint(x: w, y: h / 2)
            let bottom = CGPoint(x: w / 2, y: h), left = CGPoint(x: 0, y: h / 2)
            func poly(_ pts: [CGPoint], _ c: Color) {
                context.fill(Path { p in p.addLines(pts); p.closeSubpath() }, with: .color(c))
            }
            // Soft shadow beneath
            context.fill(Path(ellipseIn: CGRect(x: w * 0.1, y: h * 0.5, width: w * 0.8, height: size.height - h * 0.5)),
                         with: .color(Color.primaryBrown.opacity(0.06)))
            // Earth sides: left lighter, right darker
            poly([left, bottom, CGPoint(x: bottom.x, y: bottom.y + depth), CGPoint(x: left.x, y: left.y + depth)], .stoneLight)
            poly([bottom, right, CGPoint(x: right.x, y: right.y + depth), CGPoint(x: bottom.x, y: bottom.y + depth)], .stoneShade)
            // Grass top
            poly([top, right, bottom, left], Color(hex: "#C9D29A"))
            poly([CGPoint(x: w / 2, y: h * 0.12), CGPoint(x: w * 0.88, y: h / 2),
                  CGPoint(x: w / 2, y: h * 0.88), CGPoint(x: w * 0.12, y: h / 2)], Color.olive.opacity(0.18))
            // A few tufts and two small flowers
            for (x, y) in [(0.28, 0.42), (0.7, 0.36), (0.62, 0.7), (0.36, 0.66), (0.5, 0.24)] {
                context.fill(Path(ellipseIn: CGRect(x: w * x - 4, y: h * y - 2, width: 8, height: 4)), with: .color(Color.olive.opacity(0.7)))
            }
            context.fill(Path(ellipseIn: CGRect(x: w * 0.76 - 2, y: h * 0.52 - 2, width: 4, height: 4)), with: .color(.terracotta))
            context.fill(Path(ellipseIn: CGRect(x: w * 0.22 - 2, y: h * 0.56 - 2, width: 4, height: 4)), with: .color(.lavender))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Customiser

struct AvatarCustomizeView: View {
    @Environment(\.dismiss) private var dismiss
    private let storage = AvatarStorage()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ZStack {
                        GrassPlot().frame(width: 200, height: 118).offset(y: 28)
                        AvatarFigure(avatar: storage.avatar).frame(width: 60, height: 108)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    section("Name") {
                        TextField("Your name", text: storage.$name)
                            .textInputAutocapitalization(.words)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 48)
                            .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    section("Robe") { swatches(Avatar.robes, selection: storage.$robe, label: "Robe colour") }
                    section("Skin") { swatches(Avatar.skins, selection: storage.$skin, label: "Skin tone") }
                    section("Hair") {
                        HStack(spacing: 8) {
                            ForEach(Avatar.Hair.allCases) { style in
                                let selected = storage.hair == style.rawValue
                                Button(style.title) { storage.$hair.wrappedValue = style.rawValue }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(selected ? Color.onPrimary : Color.primaryBrown)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(selected ? Color.primaryBrown : Color.sand,
                                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .accessibilityAddTraits(selected ? .isSelected : [])
                            }
                        }
                        swatches(Avatar.hairColors, selection: storage.$hairColor, label: "Hair colour")
                    }
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("Your character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(Color.primaryBrown)
                }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.serifTitle(.title3))
                .foregroundStyle(Color.bodyText)
            content()
        }
    }

    private func swatches(_ colors: [String], selection: Binding<String>, label: String) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 10)], spacing: 10) {
            ForEach(colors, id: \.self) { hex in
                let selected = selection.wrappedValue == hex
                Button { selection.wrappedValue = hex } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 36, height: 36)
                        .padding(4)
                        .background(Circle().fill(selected ? Color.primaryBrown.opacity(0.85) : Color.card))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label) \((colors.firstIndex(of: hex) ?? 0) + 1)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

#Preview("Customise") {
    AvatarCustomizeView()
}

import SwiftUI
import SwiftData

// MARK: - Model

/// What your character looks like. Stored in SwiftData as `AvatarProfile`.
struct Avatar: Equatable {
    enum Hair: String, CaseIterable, Identifiable {
        case headcloth, short, long, curly, bun
        var id: String { rawValue }
        var title: String {
            switch self {
            case .headcloth: "Headcloth"
            case .short: "Short"
            case .long: "Long"
            case .curly: "Curly"
            case .bun: "Bun"
            }
        }
    }

    enum Sandals: String, CaseIterable, Identifiable {
        case none, tan, brown
        var id: String { rawValue }
        var title: String { self == .none ? "Barefoot" : rawValue.capitalized }
        var color: String? { switch self { case .none: nil; case .tan: "#C9A27A"; case .brown: "#7A5236" } }
    }

    var name = ""
    var robe = Avatar.robes[0]
    var skin = Avatar.skins[1]
    var hair: Hair = .headcloth
    var hairColor = Avatar.hairColors[0]
    var sash = Avatar.sashes[0]
    var sandals: Sandals = .tan

    static let `default` = Avatar()

    static let robes = ["#E39A7E", "#BFA9DA", "#A9B47C", "#93AECF", "#E9C77F", "#C98F6E", "#F2EBDD", "#7A4A2A"]
    static let skins = ["#F6D9C0", "#EBC3A0", "#D9A57E", "#B98159", "#8E5E3D", "#5E3D28"]
    static let hairColors = ["#FAF0DE", "#E8C192", "#B48A6A", "#8A5A3C", "#4A3326", "#2F2418", "#A9A29A"]
    static let sashes = ["#FAF0DE", "#E39A7E", "#BFA9DA", "#A9B47C", "#E9C77F", "#7A4A2A"]
}

/// Your character, saved on this device. There is one.
@Model
final class AvatarProfile {
    var name: String
    var robe: String
    var skin: String
    var hair: String
    var hairColor: String
    var sash: String
    var sandals: String

    init(_ a: Avatar) {
        name = a.name; robe = a.robe; skin = a.skin; hair = a.hair.rawValue
        hairColor = a.hairColor; sash = a.sash; sandals = a.sandals.rawValue
    }

    var avatar: Avatar {
        Avatar(name: name, robe: robe, skin: skin, hair: Avatar.Hair(rawValue: hair) ?? .headcloth,
               hairColor: hairColor, sash: sash, sandals: Avatar.Sandals(rawValue: sandals) ?? .tan)
    }

    /// Makes sure a profile exists. The first time, it carries over the character
    /// from the earlier version of the app (stored in UserDefaults), if there was one.
    @discardableResult
    static func ensure(in context: ModelContext) -> AvatarProfile {
        if let existing = try? context.fetch(FetchDescriptor<AvatarProfile>()).first { return existing }
        let d = UserDefaults.standard
        var legacy = Avatar.default
        legacy.name = d.string(forKey: LegacyAvatarKeys.name) ?? ""
        legacy.robe = d.string(forKey: LegacyAvatarKeys.robe) ?? legacy.robe
        legacy.skin = d.string(forKey: LegacyAvatarKeys.skin) ?? legacy.skin
        legacy.hair = d.string(forKey: LegacyAvatarKeys.hair).flatMap(Avatar.Hair.init(rawValue:)) ?? legacy.hair
        legacy.hairColor = d.string(forKey: LegacyAvatarKeys.hairColor) ?? legacy.hairColor
        let profile = AvatarProfile(legacy)
        context.insert(profile)
        try? context.save()
        return profile
    }
}

/// Where the character used to be stored (before SwiftData). Read once for migration.
enum LegacyAvatarKeys {
    static let name = "avatarName"
    static let robe = "avatarRobe"
    static let skin = "avatarSkin"
    static let hair = "avatarHair"
    static let hairColor = "avatarHairColor"
}

/// The current character, for views.
@propertyWrapper
struct CurrentAvatar: DynamicProperty {
    @Query private var profiles: [AvatarProfile]
    init() {}
    var wrappedValue: Avatar { profiles.first?.avatar ?? .default }
}

// MARK: - Figure

/// A chibi figure: big head, dash eyes, no mouth, soft pastel robe, sash and sandals.
/// Drawn in a 20 × 36 unit box (y down), scaled to the frame; the feet sit near the bottom.
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
            ellipse(CGRect(x: 3, y: 32.6, width: 14, height: 3.2), Color.primaryBrown.opacity(0.12))

            // Hair or cloth that falls behind the head and shoulders
            switch avatar.hair {
            case .long: rounded(CGRect(x: 2.2, y: 6, width: 15.6, height: 16), 6, hair)
            case .headcloth: rounded(CGRect(x: 2, y: 5, width: 16, height: 15), 6, hair)
            default: break
            }

            // Little robe, with the right side in shade
            let body = Path { p in
                p.move(to: CGPoint(x: 10, y: 15))
                p.addCurve(to: CGPoint(x: 16, y: 33), control1: CGPoint(x: 14.5, y: 17), control2: CGPoint(x: 16, y: 26))
                p.addLine(to: CGPoint(x: 4, y: 33))
                p.addCurve(to: CGPoint(x: 10, y: 15), control1: CGPoint(x: 4, y: 26), control2: CGPoint(x: 5.5, y: 17))
            }
            context.fill(body, with: .color(robe))
            var shaded = context
            shaded.clip(to: body)
            shaded.fill(Path(CGRect(x: 10, y: 14, width: 10, height: 20)), with: .color(Color.primaryBrown.opacity(0.10)))
            // Sash
            rounded(CGRect(x: 5.4, y: 24, width: 9.2, height: 2.4), 1.2, Color(hex: avatar.sash))
            // Sandals peeking out
            if let sandal = avatar.sandals.color {
                ellipse(CGRect(x: 5.2, y: 32.2, width: 4.2, height: 2), Color(hex: sandal))
                ellipse(CGRect(x: 10.6, y: 32.2, width: 4.2, height: 2), Color(hex: sandal))
            }

            // Big head
            ellipse(CGRect(x: 2.5, y: 1.5, width: 15, height: 14.5), skin)
            // Dash eyes, a hint of cheek, no mouth
            rounded(CGRect(x: 6.1, y: 9.4, width: 2.4, height: 0.75), 0.4, Color.bodyText.opacity(0.8))
            rounded(CGRect(x: 11.5, y: 9.4, width: 2.4, height: 0.75), 0.4, Color.bodyText.opacity(0.8))
            ellipse(CGRect(x: 5, y: 11, width: 2.6, height: 1.4), Color.terracotta.opacity(0.25))
            ellipse(CGRect(x: 12.4, y: 11, width: 2.6, height: 1.4), Color.terracotta.opacity(0.25))

            // Hair or covering on top
            switch avatar.hair {
            case .headcloth:
                ellipse(CGRect(x: 1.8, y: 0.5, width: 16.4, height: 8.2), hair)
                rounded(CGRect(x: 3, y: 5.6, width: 14, height: 1.4), 0.7, Color.terracotta.opacity(0.5))
            case .short:
                ellipse(CGRect(x: 2.8, y: 0.8, width: 14.4, height: 7.2), hair)
            case .long:
                ellipse(CGRect(x: 2.4, y: 0.6, width: 15.2, height: 7.6), hair)
            case .curly:
                for (x, y) in [(4.0, 4.8), (6.4, 2.2), (9.6, 1.2), (12.8, 2.0), (15.4, 4.4), (8.0, 3.0), (11.6, 3.2)] {
                    ellipse(CGRect(x: x - 2.4, y: y - 2.4, width: 4.8, height: 4.8), hair)
                }
            case .bun:
                ellipse(CGRect(x: 7.4, y: 0.2, width: 5.2, height: 4.2), hair)
                ellipse(CGRect(x: 2.8, y: 1.6, width: 14.4, height: 6.6), hair)
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

// MARK: - Editor

/// The quick avatar creator: used in onboarding, Settings and the home menu.
struct AvatarEditor: View {
    @Bindable var profile: AvatarProfile
    var showsName = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack {
                GrassPlot().frame(width: 200, height: 118).offset(y: 30)
                AvatarFigure(avatar: profile.avatar).frame(width: 62, height: 112)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

            if showsName {
                section("Name") {
                    TextField("Your name", text: $profile.name)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            section("Skin") { swatches(Avatar.skins, selection: $profile.skin, label: "Skin tone") }
            section("Hair") {
                chips(Avatar.Hair.allCases.map { ($0.rawValue, $0.title) }, selection: $profile.hair)
                swatches(Avatar.hairColors, selection: $profile.hairColor, label: "Hair colour")
            }
            section("Robe") { swatches(Avatar.robes, selection: $profile.robe, label: "Robe colour") }
            section("Sash") { swatches(Avatar.sashes, selection: $profile.sash, label: "Sash colour") }
            section("Sandals") { chips(Avatar.Sandals.allCases.map { ($0.rawValue, $0.title) }, selection: $profile.sandals) }
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

    private func chips(_ options: [(String, String)], selection: Binding<String>) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.0) { option in
                let selected = selection.wrappedValue == option.0
                Button(option.1) { selection.wrappedValue = option.0 }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selected ? Color.onPrimary : Color.primaryBrown)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(selected ? Color.primaryBrown : Color.sand,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityAddTraits(selected ? .isSelected : [])
            }
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

/// The editor in a sheet (from Settings or the home menu).
struct AvatarCustomizeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [AvatarProfile]

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile = profiles.first {
                    AvatarEditor(profile: profile).padding(16)
                } else {
                    ProgressView().padding(40)
                }
            }
            .themedScreen()
            .navigationTitle("Your character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { try? context.save(); dismiss() }.tint(Color.primaryBrown)
                }
            }
            .task { AvatarProfile.ensure(in: context) }
        }
    }
}

#Preview("Customise") {
    AvatarCustomizeView()
        .modelContainer(PreviewData.container)
}

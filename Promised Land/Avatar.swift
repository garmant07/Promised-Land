import SwiftUI
import SwiftData

// MARK: - Model

/// What your character looks like. Stored in SwiftData as `AvatarProfile`.
struct Avatar: Hashable {
    enum Hair: String, CaseIterable, Identifiable {
        case short, long, curly, bun, bald
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    enum Beard: String, CaseIterable, Identifiable {
        case none, stubble, short, long
        var id: String { rawValue }
        var title: String { self == .none ? "None" : rawValue.capitalized }
    }

    enum Covering: String, CaseIterable, Identifiable {
        case none, headcloth, veil, turban, wreath
        var id: String { rawValue }
        var title: String { self == .none ? "None" : rawValue.capitalized }
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
    var hair: Hair = .long
    var hairColor = Avatar.hairColors[3]
    var sash = Avatar.sashes[0]
    var sandals: Sandals = .tan
    var beard: Beard = .none
    var covering: Covering = .headcloth
    var coveringColor = Avatar.cloths[0]

    static let `default` = Avatar()

    static let robes = ["#E39A7E", "#BFA9DA", "#A9B47C", "#93AECF", "#E9C77F", "#C98F6E", "#F2EBDD", "#7A4A2A"]
    static let skins = ["#F6D9C0", "#EBC3A0", "#D9A57E", "#B98159", "#8E5E3D", "#5E3D28"]
    static let hairColors = ["#FAF0DE", "#E8C192", "#B48A6A", "#8A5A3C", "#4A3326", "#2F2418", "#A9A29A", "#EADCC9"]
    static let sashes = ["#FAF0DE", "#E39A7E", "#BFA9DA", "#A9B47C", "#E9C77F", "#7A4A2A"]
    static let cloths = ["#F1E6D7", "#FAF0DE", "#E39A7E", "#BFA9DA", "#93AECF", "#E9C77F", "#A9B47C"]

    /// A random look (keeps the name).
    func randomised() -> Avatar {
        var a = self
        a.robe = Self.robes.randomElement()!
        a.skin = Self.skins.randomElement()!
        a.hair = Hair.allCases.randomElement()!
        a.hairColor = Self.hairColors.randomElement()!
        a.sash = Self.sashes.randomElement()!
        a.sandals = Sandals.allCases.randomElement()!
        a.beard = Bool.random() ? .none : Beard.allCases.randomElement()!
        a.covering = Covering.allCases.randomElement()!
        a.coveringColor = Self.cloths.randomElement()!
        return a
    }
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
    // Added in the avatar creator rebuild; defaults keep earlier characters as they were.
    var beard: String = "none"
    /// "legacy" until edited: earlier versions had a headcloth as a hair style.
    var covering: String = "legacy"
    var coveringColor: String = ""

    init(_ a: Avatar) {
        name = a.name; robe = a.robe; skin = a.skin; hair = a.hair.rawValue
        hairColor = a.hairColor; sash = a.sash; sandals = a.sandals.rawValue
        beard = a.beard.rawValue; covering = a.covering.rawValue; coveringColor = a.coveringColor
    }

    var avatar: Avatar {
        var a = Avatar(name: name, robe: robe, skin: skin, hair: Avatar.Hair(rawValue: hair) ?? .long,
                       hairColor: hairColor, sash: sash, sandals: Avatar.Sandals(rawValue: sandals) ?? .tan,
                       beard: Avatar.Beard(rawValue: beard) ?? .none)
        if covering == "legacy" {
            // The old "headcloth" hair style becomes a headcloth in the same colour over long hair.
            a.covering = hair == "headcloth" ? .headcloth : .none
            a.coveringColor = hairColor
            if hair == "headcloth" { a.hairColor = Avatar.hairColors[3] }
        } else {
            a.covering = Avatar.Covering(rawValue: covering) ?? .none
            a.coveringColor = coveringColor.isEmpty ? Avatar.cloths[0] : coveringColor
        }
        return a
    }

    /// Writes a whole look back (from the editor).
    func apply(_ a: Avatar) {
        robe = a.robe; skin = a.skin; hair = a.hair.rawValue; hairColor = a.hairColor; sash = a.sash
        sandals = a.sandals.rawValue; beard = a.beard.rawValue; covering = a.covering.rawValue; coveringColor = a.coveringColor
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
        let oldHair = d.string(forKey: LegacyAvatarKeys.hair)
        legacy.hair = oldHair.flatMap(Avatar.Hair.init(rawValue:)) ?? legacy.hair
        if let oldColor = d.string(forKey: LegacyAvatarKeys.hairColor) {
            if oldHair == "headcloth" { legacy.coveringColor = oldColor } else { legacy.hairColor = oldColor }
        }
        if let oldHair, oldHair != "headcloth" { legacy.covering = .none }
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

            let cloth = Color(hex: avatar.coveringColor)
            // Hair or cloth that falls behind the head and shoulders
            switch avatar.covering {
            case .headcloth: rounded(CGRect(x: 2, y: 5, width: 16, height: 15), 6, cloth)
            case .veil: rounded(CGRect(x: 1.6, y: 4, width: 16.8, height: 21), 7, cloth)
            default: if avatar.hair == .long { rounded(CGRect(x: 2.2, y: 6, width: 15.6, height: 16), 6, hair) }
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

            // Beard (under the eyes, over the chin)
            let beardColor = hair
            switch avatar.beard {
            case .none: break
            case .stubble:
                ellipse(CGRect(x: 5.2, y: 11.6, width: 9.6, height: 4.2), beardColor.opacity(0.35))
            case .short:
                let b = Path { p in
                    p.move(to: CGPoint(x: 4.2, y: 10.8))
                    p.addQuadCurve(to: CGPoint(x: 10, y: 17.4), control: CGPoint(x: 4.6, y: 17))
                    p.addQuadCurve(to: CGPoint(x: 15.8, y: 10.8), control: CGPoint(x: 15.4, y: 17))
                    p.addQuadCurve(to: CGPoint(x: 4.2, y: 10.8), control: CGPoint(x: 10, y: 13.6))
                }
                context.fill(b, with: .color(beardColor))
            case .long:
                let b = Path { p in
                    p.move(to: CGPoint(x: 3.8, y: 10.2))
                    p.addQuadCurve(to: CGPoint(x: 10, y: 22.5), control: CGPoint(x: 3.6, y: 21))
                    p.addQuadCurve(to: CGPoint(x: 16.2, y: 10.2), control: CGPoint(x: 16.4, y: 21))
                    p.addQuadCurve(to: CGPoint(x: 3.8, y: 10.2), control: CGPoint(x: 10, y: 13.4))
                }
                context.fill(b, with: .color(beardColor))
            }

            // Hair, then any covering, on top
            switch avatar.hair {
            case .bald:
                break
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
            switch avatar.covering {
            case .none: break
            case .headcloth:
                ellipse(CGRect(x: 1.8, y: 0.5, width: 16.4, height: 8.2), cloth)
                rounded(CGRect(x: 3, y: 5.6, width: 14, height: 1.4), 0.7, Color.terracotta.opacity(0.5))
            case .veil:
                ellipse(CGRect(x: 1.6, y: 0.2, width: 16.8, height: 9), cloth)
                rounded(CGRect(x: 2.4, y: 5.2, width: 2.2, height: 12), 1.1, cloth)
                rounded(CGRect(x: 15.4, y: 5.2, width: 2.2, height: 12), 1.1, cloth)
            case .turban:
                ellipse(CGRect(x: 2.4, y: -0.6, width: 15.2, height: 8.6), cloth)
                rounded(CGRect(x: 2.6, y: 4.2, width: 14.8, height: 2.6), 1.3, Color.primaryBrown.opacity(0.12))
                ellipse(CGRect(x: 8.6, y: 2.2, width: 2.8, height: 2.8), Color.terracotta.opacity(0.6))
            case .wreath:
                for i in 0..<9 {
                    let a = Double(i) / 8 * .pi
                    ellipse(CGRect(x: 10 - cos(a) * 7.6 - 1.4, y: 5 - sin(a) * 3 - 0.9, width: 2.8, height: 1.8), Color(hex: "#A9B47C"))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Editor

/// The avatar creator: a live preview, every option, and Randomise. Used in onboarding and
/// from your Profile.
struct AvatarEditor: View {
    @Bindable var profile: AvatarProfile
    var showsName = true
    /// Onboarding shows the preview inline; the full-screen creator pins it above the options.
    var showsPreview = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showsPreview {
                AvatarPreview(avatar: profile.avatar)
                randomiseButton
            }
            if showsName {
                section("Name") {
                    TextField("Your name", text: $profile.name)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            section("Skin") { swatches(Avatar.skins, selection: binding(\.skin), label: "Skin tone") }
            section("Hair") {
                chips(Avatar.Hair.allCases.map { ($0.rawValue, $0.title) }, selection: Binding(
                    get: { profile.avatar.hair.rawValue },
                    set: { v in update { $0.hair = Avatar.Hair(rawValue: v) ?? .long } }))
                swatches(Avatar.hairColors, selection: binding(\.hairColor), label: "Hair colour")
            }
            section("Beard") {
                chips(Avatar.Beard.allCases.map { ($0.rawValue, $0.title) }, selection: Binding(
                    get: { profile.avatar.beard.rawValue },
                    set: { v in update { $0.beard = Avatar.Beard(rawValue: v) ?? .none } }))
            }
            section("Head covering") {
                chips(Avatar.Covering.allCases.map { ($0.rawValue, $0.title) }, selection: Binding(
                    get: { profile.avatar.covering.rawValue },
                    set: { v in update { $0.covering = Avatar.Covering(rawValue: v) ?? .none } }))
                if profile.avatar.covering != .none {
                    swatches(Avatar.cloths, selection: binding(\.coveringColor), label: "Covering colour")
                }
            }
            section("Robe") { swatches(Avatar.robes, selection: binding(\.robe), label: "Robe colour") }
            section("Sash") { swatches(Avatar.sashes, selection: binding(\.sash), label: "Sash colour") }
            section("Sandals") {
                chips(Avatar.Sandals.allCases.map { ($0.rawValue, $0.title) }, selection: Binding(
                    get: { profile.avatar.sandals.rawValue },
                    set: { v in update { $0.sandals = Avatar.Sandals(rawValue: v) ?? .tan } }))
            }
        }
    }

    var randomiseButton: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) { update { $0 = $0.randomised() } }
        } label: {
            Label("Randomise", systemImage: "dice")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SoftButtonStyle())
    }

    /// Changes the look through `Avatar`, so legacy profiles are converted on first edit.
    private func update(_ change: (inout Avatar) -> Void) {
        var a = profile.avatar
        change(&a)
        profile.apply(a)
    }

    private func binding(_ key: WritableKeyPath<Avatar, String>) -> Binding<String> {
        Binding(get: { profile.avatar[keyPath: key] }, set: { v in update { $0[keyPath: key] = v } })
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

/// The character standing on a little plot of sand, as on the island.
struct AvatarPreview: View {
    let avatar: Avatar
    var height: CGFloat = 112

    var body: some View {
        ZStack {
            SandPlot().frame(width: height * 1.8, height: height * 1.05).offset(y: height * 0.27)
            AvatarFigure(avatar: avatar).frame(width: height * 0.55, height: height)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .accessibilityElement()
        .accessibilityLabel("Preview of your character")
    }
}

/// A single isometric plot of sand with soft earth sides, in the island's style.
struct SandPlot: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, depth = size.height * 0.16
            let h = (size.height - depth)
            let top = CGPoint(x: w / 2, y: 0), right = CGPoint(x: w, y: h / 2)
            let bottom = CGPoint(x: w / 2, y: h), left = CGPoint(x: 0, y: h / 2)
            func poly(_ pts: [CGPoint], _ c: Color) {
                context.fill(Path { p in p.addLines(pts); p.closeSubpath() }, with: .color(c))
            }
            poly([left, bottom, CGPoint(x: bottom.x, y: bottom.y + depth), CGPoint(x: left.x, y: left.y + depth)], Earthy.strataLeftTop)
            poly([bottom, right, CGPoint(x: right.x, y: right.y + depth), CGPoint(x: bottom.x, y: bottom.y + depth)], Earthy.strataRightTop)
            poly([top, right, bottom, left], Earthy.ground)
            context.fill(Path(ellipseIn: CGRect(x: w * 0.3, y: h * 0.3, width: w * 0.4, height: h * 0.3)), with: .color(Earthy.groundLight))
            for (x, y) in [(0.24, 0.48), (0.74, 0.5)] {
                context.fill(Path(ellipseIn: CGRect(x: w * x - 5, y: h * y - 3, width: 10, height: 6)), with: .color(Earthy.bush))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The avatar creator in a sheet (from your Profile or Settings): the preview stays in view
/// while you scroll the options.
struct AvatarCustomizeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [AvatarProfile]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let profile = profiles.first {
                    VStack(spacing: 8) {
                        AvatarPreview(avatar: profile.avatar, height: 104)
                        AvatarEditor(profile: profile, showsName: false, showsPreview: false).randomiseButton
                            .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 10)
                    .background(Color.cream)
                    Divider().opacity(0.4)
                    ScrollView {
                        AvatarEditor(profile: profile, showsPreview: false).padding(16)
                    }
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

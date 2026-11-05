import SwiftUI
import SwiftData

// MARK: - Model

/// What your character looks like: a name and a layered look (`AvatarConfig`).
struct Avatar: Hashable {
    var name = ""
    var config = AvatarConfig()

    static let `default` = Avatar()
}

/// Your character, saved on this device. There is one.
@Model
final class AvatarProfile {
    var name: String
    // The first avatar's fields, kept so older characters can be carried over.
    var robe: String
    var skin: String
    var hair: String
    var hairColor: String
    var sash: String
    var sandals: String
    var beard: String = "none"
    /// "legacy" until edited: earlier versions had a headcloth as a hair style.
    var covering: String = "legacy"
    var coveringColor: String = ""
    /// The layered look (JSON `AvatarConfig`). Nil until first saved: the look is then worked
    /// out from the fields above.
    var configData: Data? = nil

    init(_ a: Avatar) {
        name = a.name
        robe = a.config.robeColour.hex; skin = a.config.skin.hex; hair = "long"; hairColor = a.config.hairColour.hex
        sash = "#7A4A2A"; sandals = "tan"
        configData = try? JSONEncoder().encode(a.config)
    }

    var config: AvatarConfig {
        if let configData, let c = try? JSONDecoder().decode(AvatarConfig.self, from: configData) { return c }
        return .migrated(robe: robe, skin: skin, hair: hair, hairColor: hairColor, sash: sash, sandals: sandals,
                         beard: beard, covering: covering, coveringColor: coveringColor)
    }

    var avatar: Avatar { Avatar(name: name, config: config) }

    /// Saves a new look.
    func apply(_ config: AvatarConfig) {
        configData = try? JSONEncoder().encode(config)
    }

    /// Makes sure a profile exists. The first time, it carries over the character
    /// from the earlier version of the app (stored in UserDefaults), if there was one.
    @discardableResult
    static func ensure(in context: ModelContext) -> AvatarProfile {
        if let existing = try? context.fetch(FetchDescriptor<AvatarProfile>()).first { return existing }
        let d = UserDefaults.standard
        var legacy = Avatar.default
        legacy.name = d.string(forKey: LegacyAvatarKeys.name) ?? ""
        if d.string(forKey: LegacyAvatarKeys.robe) != nil {
            legacy.config = .migrated(robe: d.string(forKey: LegacyAvatarKeys.robe) ?? "#E39A7E",
                                      skin: d.string(forKey: LegacyAvatarKeys.skin) ?? "#EBC3A0",
                                      hair: d.string(forKey: LegacyAvatarKeys.hair) ?? "long",
                                      hairColor: d.string(forKey: LegacyAvatarKeys.hairColor) ?? "#8A5A3C",
                                      sash: "#7A4A2A", sandals: "tan", beard: "none", covering: "legacy", coveringColor: "")
        }
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

/// Your character as a view (the layered avatar). Kept as a name for existing call sites.
struct AvatarFigure: View {
    let avatar: Avatar

    var body: some View {
        AvatarView(config: avatar.config)
    }
}

// MARK: - Editor

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

/// The avatar creator in a sheet (from your Profile or Settings).
struct AvatarCustomizeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AvatarCreatorView(onDone: { dismiss() })
    }
}

#Preview("Customise") {
    AvatarCustomizeView()
        .modelContainer(PreviewData.container)
}

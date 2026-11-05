import SwiftUI

// The avatar's parts. Every layer is an enum of options, so new options are just data.
// Colours are kept as hex strings and applied as tints. Options are drawn from the features of
// the 12 character designs (the char_ assets).

/// A colour option with a name for VoiceOver and a hex value.
nonisolated protocol AvatarSwatch: CaseIterable, Hashable, Codable, RawRepresentable where RawValue == String {
    var hex: String { get }
}

extension AvatarSwatch {
    var color: Color { Color(hex: hex) }
    var title: String { rawValue.splitCamel }
}

/// An option of a layer.
nonisolated protocol AvatarOption: CaseIterable, Hashable, Codable, RawRepresentable where RawValue == String {}

extension AvatarOption {
    var title: String { rawValue.splitCamel }
}

nonisolated enum SkinTone: String, AvatarSwatch {
    case porcelain, light, warm, tan, brown, deep
    var hex: String {
        switch self {
        case .porcelain: "#F8E0C8"
        case .light: "#F4CDA8"
        case .warm: "#EDBB92"
        case .tan: "#CF9670"
        case .brown: "#9C6847"
        case .deep: "#6E4630"
        }
    }
}

nonisolated enum HairStyle: String, AvatarOption {
    case bald, baldWithSides, shortCurly, longWavy, longStraight
}

nonisolated enum HairColour: String, AvatarSwatch {
    case darkBrown, brown, auburn, lightBrown, grey, white
    var hex: String {
        switch self {
        case .darkBrown: "#4A3326"
        case .brown: "#6E4A33"
        case .auburn: "#9A5536"
        case .lightBrown: "#B48A6A"
        case .grey: "#A9A29A"
        case .white: "#EFE7DB"
        }
    }
}

nonisolated enum BeardStyle: String, AvatarOption {
    case none, short, full, longFlowing
}

nonisolated enum HeadCovering: String, AvatarOption {
    case none, headband, veil, veilWithWrap, headdress, crown
}

nonisolated enum RobeStyle: String, AvatarOption {
    case longRobe, robeWithPanel, kneeTunic, sleevelessTunic
}

nonisolated enum ClothColour: String, AvatarSwatch {
    case cream, sand, ochre, rose, sage, olive, skyBlue, slatePurple, terracotta
    var hex: String {
        switch self {
        case .cream: "#F2E8D5"
        case .sand: "#E9D3AA"
        case .ochre: "#D9A54E"
        case .rose: "#E7A79A"
        case .sage: "#A9B88F"
        case .olive: "#8E9A5E"
        case .skyBlue: "#9DB8D2"
        case .slatePurple: "#9B8DB3"
        case .terracotta: "#D98A6C"
        }
    }
}

nonisolated enum SashStyle: String, AvatarOption {
    case none, brownBelt, goldTrim, redSash
}

nonisolated enum CloakStyle: String, AvatarOption {
    case none, shoulderCloak, longCloak, redCape, coat
}

nonisolated enum HeldItem: String, AvatarOption {
    case none, staff, shepherdsCrook, scroll, book, wheatBundle, scepter, pouch, dove
}

nonisolated enum SandalColour: String, AvatarSwatch {
    case brown, darkBrown, tan
    var hex: String {
        switch self {
        case .brown: "#8E603F"
        case .darkBrown: "#5E3D28"
        case .tan: "#C9A27A"
        }
    }
}

/// A complete look. Codable, and tolerant of missing fields, so older saved looks still load.
nonisolated struct AvatarConfig: Hashable, Codable, Sendable {
    static let currentVersion = 1

    var version = AvatarConfig.currentVersion
    var skin: SkinTone = .warm
    var hair: HairStyle = .longStraight
    var hairColour: HairColour = .brown
    var beard: BeardStyle = .none
    var head: HeadCovering = .veil
    var headColour: ClothColour = .cream
    var robe: RobeStyle = .longRobe
    var robeColour: ClothColour = .terracotta
    var sash: SashStyle = .brownBelt
    var cloak: CloakStyle = .none
    var cloakColour: ClothColour = .sand
    var item: HeldItem = .none
    var sandals: SandalColour = .brown

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AvatarConfig()
        version = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? d.version
        skin = (try? c.decodeIfPresent(SkinTone.self, forKey: .skin)) ?? d.skin
        hair = (try? c.decodeIfPresent(HairStyle.self, forKey: .hair)) ?? d.hair
        hairColour = (try? c.decodeIfPresent(HairColour.self, forKey: .hairColour)) ?? d.hairColour
        beard = (try? c.decodeIfPresent(BeardStyle.self, forKey: .beard)) ?? d.beard
        head = (try? c.decodeIfPresent(HeadCovering.self, forKey: .head)) ?? d.head
        headColour = (try? c.decodeIfPresent(ClothColour.self, forKey: .headColour)) ?? d.headColour
        robe = (try? c.decodeIfPresent(RobeStyle.self, forKey: .robe)) ?? d.robe
        robeColour = (try? c.decodeIfPresent(ClothColour.self, forKey: .robeColour)) ?? d.robeColour
        sash = (try? c.decodeIfPresent(SashStyle.self, forKey: .sash)) ?? d.sash
        cloak = (try? c.decodeIfPresent(CloakStyle.self, forKey: .cloak)) ?? d.cloak
        cloakColour = (try? c.decodeIfPresent(ClothColour.self, forKey: .cloakColour)) ?? d.cloakColour
        item = (try? c.decodeIfPresent(HeldItem.self, forKey: .item)) ?? d.item
        sandals = (try? c.decodeIfPresent(SandalColour.self, forKey: .sandals)) ?? d.sandals
    }

    /// A random look that hangs together: soft robe and cloak colours that differ, coverings
    /// that suit the hair, and an item only some of the time.
    static func random<G: RandomNumberGenerator>(using g: inout G) -> AvatarConfig {
        var a = AvatarConfig()
        a.skin = SkinTone.allCases.randomElement(using: &g)!
        a.hair = HairStyle.allCases.randomElement(using: &g)!
        a.hairColour = HairColour.allCases.randomElement(using: &g)!
        a.beard = [.none, .none, .short, .full, .longFlowing].randomElement(using: &g)!
        let robes: [ClothColour] = [.cream, .sand, .skyBlue, .rose, .sage, .slatePurple, .terracotta]
        a.robeColour = robes.randomElement(using: &g)!
        a.robe = RobeStyle.allCases.randomElement(using: &g)!
        a.cloak = [.none, .none, .shoulderCloak, .longCloak, .coat, .redCape].randomElement(using: &g)!
        a.cloakColour = ClothColour.allCases.filter { $0 != a.robeColour }.randomElement(using: &g)!
        a.sash = SashStyle.allCases.randomElement(using: &g)!
        // Veils go with longer hair; crowns with a red cape now and then.
        a.head = a.hair == .longStraight || a.hair == .longWavy
            ? [.none, .veil, .veilWithWrap, .headband].randomElement(using: &g)!
            : [.none, .none, .headband, .headdress, .crown].randomElement(using: &g)!
        if a.head == .veilWithWrap { a.beard = .none }
        a.headColour = [.cream, .sand, .rose, .skyBlue, .ochre].randomElement(using: &g)!
        a.item = Bool.random(using: &g) ? .none : HeldItem.allCases.randomElement(using: &g)!
        a.sandals = SandalColour.allCases.randomElement(using: &g)!
        return a
    }

    static func random() -> AvatarConfig {
        var g = SystemRandomNumberGenerator()
        return random(using: &g)
    }
}

/// Looks taken from the character designs ("Start from a character").
enum AvatarPresets {
    static func config(for id: String) -> AvatarConfig {
        var a = AvatarConfig()
        a.cloak = .none; a.head = .none; a.sash = .none; a.item = .none; a.beard = .none
        switch id {
        case "jesus":
            a.skin = .warm; a.hair = .longWavy; a.hairColour = .auburn; a.beard = .full
            a.robe = .longRobe; a.robeColour = .cream; a.sash = .redSash
        case "mary":
            a.skin = .light; a.hair = .longStraight; a.hairColour = .brown; a.head = .veil; a.headColour = .cream
            a.robe = .longRobe; a.robeColour = .skyBlue
        case "david":
            a.skin = .warm; a.hair = .shortCurly; a.hairColour = .auburn; a.head = .headband; a.headColour = .ochre
            a.robe = .kneeTunic; a.robeColour = .cream; a.cloak = .shoulderCloak; a.cloakColour = .sage
            a.sash = .brownBelt; a.item = .shepherdsCrook
        case "abraham":
            a.skin = .warm; a.hair = .longStraight; a.hairColour = .white; a.beard = .longFlowing
            a.head = .headdress; a.headColour = .cream; a.robe = .longRobe; a.robeColour = .cream
            a.cloak = .coat; a.cloakColour = .ochre; a.item = .staff
        case "sarah":
            a.skin = .light; a.hair = .longStraight; a.hairColour = .lightBrown; a.head = .veilWithWrap; a.headColour = .rose
            a.robe = .longRobe; a.robeColour = .rose; a.sash = .brownBelt
        case "ruth":
            a.skin = .light; a.hair = .longStraight; a.hairColour = .brown; a.head = .veil; a.headColour = .cream
            a.robe = .robeWithPanel; a.robeColour = .sage; a.item = .wheatBundle
        case "daniel":
            a.skin = .warm; a.hair = .shortCurly; a.hairColour = .lightBrown
            a.robe = .robeWithPanel; a.robeColour = .slatePurple; a.sash = .goldTrim
        case "samson":
            a.skin = .tan; a.hair = .longWavy; a.hairColour = .auburn; a.beard = .full; a.head = .headband; a.headColour = .ochre
            a.robe = .sleevelessTunic; a.robeColour = .sand; a.sash = .brownBelt
        case "solomon":
            a.skin = .warm; a.hair = .shortCurly; a.hairColour = .auburn; a.head = .crown
            a.robe = .longRobe; a.robeColour = .cream; a.cloak = .redCape; a.sash = .brownBelt; a.item = .scepter
        case "paul":
            a.skin = .warm; a.hair = .baldWithSides; a.hairColour = .brown; a.beard = .full
            a.robe = .longRobe; a.robeColour = .cream; a.cloak = .longCloak; a.cloakColour = .slatePurple; a.item = .book
        case "john":
            a.skin = .warm; a.hair = .shortCurly; a.hairColour = .auburn
            a.robe = .longRobe; a.robeColour = .sage; a.item = .scroll
        case "moses":
            a.skin = .warm; a.hair = .longStraight; a.hairColour = .white; a.beard = .longFlowing
            a.robe = .longRobe; a.robeColour = .cream; a.cloak = .coat; a.cloakColour = .terracotta
            a.sash = .brownBelt; a.item = .staff
        case "jonah":
            a.skin = .warm; a.hair = .shortCurly; a.hairColour = .darkBrown; a.beard = .short
            a.robe = .longRobe; a.robeColour = .cream; a.cloak = .longCloak; a.cloakColour = .skyBlue
            a.sash = .brownBelt; a.item = .pouch
        default:
            return AvatarConfig()
        }
        return a
    }
}

// MARK: - Migration from the first avatar

extension AvatarConfig {
    /// The nearest new look to an avatar saved by an earlier version (hex colours and the old
    /// hair, beard and covering names).
    static func migrated(robe: String, skin: String, hair: String, hairColor: String, sash: String,
                         sandals: String, beard: String, covering: String, coveringColor: String) -> AvatarConfig {
        var a = AvatarConfig()
        a.skin = nearest(SkinTone.allCases, to: skin)
        a.robeColour = nearest(ClothColour.allCases, to: robe)
        a.hairColour = nearest(HairColour.allCases, to: hairColor)
        switch hair {
        case "bald": a.hair = .bald
        case "short", "curly": a.hair = .shortCurly
        default: a.hair = .longStraight // long, bun, headcloth
        }
        switch beard {
        case "stubble", "short": a.beard = .short
        case "long": a.beard = .longFlowing
        default: a.beard = .none
        }
        switch covering {
        case "headcloth", "veil": a.head = .veil
        case "turban": a.head = .headdress
        case "wreath": a.head = .headband
        case "legacy": a.head = hair == "headcloth" ? .veil : .none
        default: a.head = .none
        }
        let cloth = covering == "legacy" ? hairColor : coveringColor
        a.headColour = cloth.isEmpty ? .cream : nearest(ClothColour.allCases, to: cloth)
        if covering == "legacy" && hair == "headcloth" { a.hairColour = .brown }
        switch sash.uppercased() {
        case "#7A4A2A": a.sash = .brownBelt
        case "#E9C77F": a.sash = .goldTrim
        case "#E39A7E": a.sash = .redSash
        default: a.sash = .none
        }
        a.sandals = sandals == "brown" ? .darkBrown : sandals == "tan" ? .tan : .brown
        a.cloak = .none
        a.item = .none
        return a
    }

    private static func nearest<S: AvatarSwatch>(_ options: S.AllCases, to hex: String) -> S {
        let target = RGBValue(hex: hex)
        return options.min { RGBValue(hex: $0.hex).distance(to: target) < RGBValue(hex: $1.hex).distance(to: target) }!
    }
}

/// A colour as numbers, for matching and shading.
nonisolated struct RGBValue: Hashable, Sendable {
    var r: Double, g: Double, b: Double

    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let v = UInt64(s, radix: 16) ?? 0
        r = Double((v >> 16) & 0xFF) / 255; g = Double((v >> 8) & 0xFF) / 255; b = Double(v & 0xFF) / 255
    }

    func distance(to o: RGBValue) -> Double { pow(r - o.r, 2) + pow(g - o.g, 2) + pow(b - o.b, 2) }

    /// Darker (< 1) or lighter (> 1).
    func shaded(_ k: Double) -> RGBValue {
        k < 1 ? RGBValue(r: r * k, g: g * k, b: b * k)
              : RGBValue(r: r + (1 - r) * (k - 1), g: g + (1 - g) * (k - 1), b: b + (1 - b) * (k - 1))
    }

    var color: Color { Color(red: r, green: g, blue: b) }
}

extension String {
    /// "longWavy" → "Long wavy".
    var splitCamel: String {
        var out = ""
        for ch in self {
            if ch.isUppercase { out += " " + ch.lowercased() } else { out.append(ch) }
        }
        return out.prefix(1).uppercased() + out.dropFirst()
    }
}

/// Who's reading, roughly (used to pitch wording; nothing is shared).
enum AgeGroup: String, CaseIterable, Identifiable {
    case under13 = "Under 13", teen = "13–17", adult = "18 and over"
    var id: String { rawValue }
}

/// Choose an age group (onboarding and Settings).
struct AgeGroupPicker: View {
    @Binding var selection: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Who's reading?")
                .font(.serifTitle(.largeTitle))
                .foregroundStyle(Color.bodyText)
            Text("This only shapes the wording. It stays on this device.")
                .font(.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                ForEach(AgeGroup.allCases) { group in
                    let selected = selection == group.rawValue
                    Button { selection = group.rawValue } label: {
                        HStack {
                            Text(group.rawValue).font(.headline)
                            Spacer()
                            if selected { Image(systemName: "checkmark.circle.fill") }
                        }
                        .foregroundStyle(selected ? Color.onPrimary : Color.primaryBrown)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 54)
                        .background(selected ? Color.primaryBrown : Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Spacer()
        }
    }
}

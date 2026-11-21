import Foundation

nonisolated enum AvatarCreatorTab: String, CaseIterable, Identifiable {
    case skin, hair, beard, head, robe, cloak, item, sandals

    var id: String { rawValue }

    var title: String {
        rawValue == "robe" ? "Clothes" : rawValue.capitalized
    }
}

nonisolated enum AvatarCreatorRules {
    static func tabs(for sex: AvatarSex) -> [AvatarCreatorTab] {
        switch sex {
        case .male: [.skin, .hair, .beard, .head, .robe, .cloak, .item, .sandals]
        case .female: [.skin, .hair, .head, .robe, .cloak, .item, .sandals]
        }
    }

    static func hair(for sex: AvatarSex) -> [HairStyle] { AvatarSexRules.allowedHair(for: sex) }
    static func beard(for sex: AvatarSex) -> [BeardStyle] { AvatarSexRules.allowedBeard(for: sex) }
    static func head(for sex: AvatarSex) -> [HeadCovering] { AvatarSexRules.allowedHeadCovering(for: sex) }
    static func robe(for sex: AvatarSex) -> [RobeStyle] { AvatarSexRules.allowedRobe(for: sex) }

    @MainActor static func presets(for sex: AvatarSex) -> [String] {
        PresetAccess.ids.filter { AvatarPresets.config(for: $0).sex == sex }
    }
}

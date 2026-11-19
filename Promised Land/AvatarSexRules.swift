import Foundation

/// The option sets and conversions used by the next avatar editor stage.
nonisolated enum AvatarSexRules {
    static func allowedHair(for sex: AvatarSex?) -> [HairStyle] {
        switch sex {
        case .male: [.bald, .baldWithSides, .shortCurly, .longWavy, .longStraight]
        case .female:
            HairStyle.allCases.filter { ["longStraight", "longWavy", "shortCurly", "braid", "bun"].contains($0.rawValue) }
        case nil: HairStyle.allCases
        }
    }

    static func allowedBeard(for sex: AvatarSex?) -> [BeardStyle] {
        switch sex {
        case .female: [.none]
        case .male, nil: BeardStyle.allCases
        }
    }

    static func allowedHeadCovering(for sex: AvatarSex?) -> [HeadCovering] {
        switch sex {
        case .male: [.none, .headband, .headdress, .crown]
        case .female:
            HeadCovering.allCases.filter { ["none", "veil", "veilWithWrap", "queenCrown"].contains($0.rawValue) }
        case nil: HeadCovering.allCases
        }
    }

    static func allowedRobe(for sex: AvatarSex?) -> [RobeStyle] {
        switch sex {
        case .male: [.longRobe, .robeWithPanel, .kneeTunic, .sleevelessTunic]
        case .female: [.longRobe, .robeWithPanel]
        case nil: RobeStyle.allCases
        }
    }

    static func defaults(for sex: AvatarSex) -> AvatarConfig {
        var config = AvatarConfig()
        config.sex = sex
        switch sex {
        case .male:
            config.skin = .warm
            config.hair = .shortCurly
            config.hairColour = .darkBrown
            config.beard = .short
            config.head = .none
            config.robe = .longRobe
            config.robeColour = .skyBlue
            config.sash = .brownBelt
            config.cloak = .none
            config.item = .none
            config.sandals = .brown
        case .female:
            config.skin = .warm
            config.hair = .longWavy
            config.hairColour = .darkBrown
            config.beard = .none
            config.head = .none
            config.robe = .robeWithPanel
            config.robeColour = .rose
            config.sash = .goldTrim
            config.cloak = .none
            config.item = .none
            config.sandals = .brown
        }
        return config
    }
}

extension AvatarConfig {
    /// Chooses a side for a pre-update look, retaining allowed features and colours.
    func converted(to sex: AvatarSex) -> AvatarConfig {
        var result = self
        result.sex = sex
        if !AvatarSexRules.allowedHair(for: sex).contains(result.hair) {
            result.hair = AvatarSexRules.defaults(for: sex).hair
        }
        if !AvatarSexRules.allowedBeard(for: sex).contains(result.beard) {
            result.beard = AvatarSexRules.defaults(for: sex).beard
        }
        if !AvatarSexRules.allowedHeadCovering(for: sex).contains(result.head) {
            result.head = AvatarSexRules.defaults(for: sex).head
        }
        if !AvatarSexRules.allowedRobe(for: sex).contains(result.robe) {
            result.robe = AvatarSexRules.defaults(for: sex).robe
        }
        return result
    }

    /// Changes sides using that side's look, retaining only the skin tone.
    func switched(to sex: AvatarSex) -> AvatarConfig {
        var result = AvatarSexRules.defaults(for: sex)
        result.skin = skin
        return result
    }

    static func random<G: RandomNumberGenerator>(for sex: AvatarSex, using g: inout G) -> AvatarConfig {
        var result = AvatarConfig()
        result.sex = sex
        result.skin = SkinTone.allCases.randomElement(using: &g)!
        result.hair = AvatarSexRules.allowedHair(for: sex).randomElement(using: &g)!
        result.hairColour = HairColour.allCases.randomElement(using: &g)!
        result.beard = AvatarSexRules.allowedBeard(for: sex).randomElement(using: &g)!
        let robes: [ClothColour] = [.cream, .sand, .skyBlue, .rose, .sage, .slatePurple, .terracotta]
        result.robeColour = robes.randomElement(using: &g)!
        result.robe = AvatarSexRules.allowedRobe(for: sex).randomElement(using: &g)!
        result.cloak = [.none, .none, .shoulderCloak, .longCloak, .coat, .redCape].randomElement(using: &g)!
        result.cloakColour = ClothColour.allCases.filter { $0 != result.robeColour }.randomElement(using: &g)!
        result.sash = SashStyle.allCases.randomElement(using: &g)!
        result.head = AvatarSexRules.allowedHeadCovering(for: sex).randomElement(using: &g)!
        if result.head == .veilWithWrap { result.beard = .none }
        result.headColour = [.cream, .sand, .rose, .skyBlue, .ochre].randomElement(using: &g)!
        result.item = Bool.random(using: &g) ? .none : HeldItem.allCases.randomElement(using: &g)!
        result.sandals = SandalColour.allCases.randomElement(using: &g)!
        return result
    }

    static func random(for sex: AvatarSex) -> AvatarConfig {
        var g = SystemRandomNumberGenerator()
        return random(for: sex, using: &g)
    }
}

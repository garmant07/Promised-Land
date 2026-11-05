import SwiftUI

/// One tab of the avatar creator: rendered thumbnails for the part's options, and colour
/// swatches beneath where the part has a colour.
struct AvatarPartPicker: View {
    let tab: AvatarCreatorView.Tab
    let config: AvatarConfig
    var onChange: (AvatarConfig) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch tab {
            case .skin:
                thumbnails(SkinTone.allCases, \.skin)
            case .hair:
                thumbnails(HairStyle.allCases, \.hair)
                swatches("Hair colour", HairColour.allCases, \.hairColour)
            case .beard:
                thumbnails(BeardStyle.allCases, \.beard)
                swatches("Colour (matches hair)", HairColour.allCases, \.hairColour)
            case .head:
                thumbnails(HeadCovering.allCases, \.head)
                if config.head != .none && config.head != .crown {
                    swatches("Cloth", ClothColour.allCases, \.headColour)
                }
            case .robe:
                thumbnails(RobeStyle.allCases, \.robe)
                swatches("Robe colour", ClothColour.allCases, \.robeColour)
                label("Sash or trim")
                thumbnails(SashStyle.allCases, \.sash)
            case .cloak:
                thumbnails(CloakStyle.allCases, \.cloak)
                if config.cloak != .none && config.cloak != .redCape {
                    swatches("Cloak colour", ClothColour.allCases, \.cloakColour)
                }
            case .item:
                thumbnails(HeldItem.allCases, \.item)
            case .sandals:
                swatches("Sandals", SandalColour.allCases, \.sandals)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Color.secondaryText)
    }

    /// A row of the avatar drawn with each option.
    private func thumbnails<O: CaseIterable & Hashable & RawRepresentable>(_ options: O.AllCases, _ key: WritableKeyPath<AvatarConfig, O>) -> some View
    where O.RawValue == String {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(options), id: \.self) { option in
                    let selected = config[keyPath: key] == option
                    Button {
                        var c = config
                        c[keyPath: key] = option
                        onChange(c)
                    } label: {
                        VStack(spacing: 4) {
                            AvatarView(config: { var c = config; c[keyPath: key] = option; return c }())
                                .frame(width: 58, height: 92)
                            Text(option.rawValue.splitCamel)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.bodyText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(width: 70)
                        }
                        .padding(6)
                        .background(selected ? Color.wheat.opacity(0.55) : Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(selected ? Color.primaryBrown : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.rawValue.splitCamel)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private func swatches<S: AvatarSwatch>(_ title: String, _ options: S.AllCases, _ key: WritableKeyPath<AvatarConfig, S>) -> some View
    where S.AllCases: RandomAccessCollection {
        VStack(alignment: .leading, spacing: 6) {
            label(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(options), id: \.self) { option in
                        let selected = config[keyPath: key] == option
                        Button {
                            var c = config
                            c[keyPath: key] = option
                            onChange(c)
                        } label: {
                            Circle()
                                .fill(option.color)
                                .frame(width: 34, height: 34)
                                .padding(5)
                                .background(Circle().fill(selected ? Color.primaryBrown.opacity(0.85) : Color.card))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.title)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
    }
}

/// "Start from a character": the 12 character designs (and Jonah). Each is locked until that
/// character's journey is complete.
struct CharacterPresetPicker: View {
    var onPick: (AvatarConfig) -> Void
    @ProgressQuery private var progress: GameProgress
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let unlocked = PresetAccess.unlocked(progress)
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                    ForEach(PresetAccess.ids, id: \.self) { id in
                        let open = unlocked.contains(id)
                        Button { if open { onPick(AvatarPresets.config(for: id)) } } label: {
                            VStack(spacing: 6) {
                                CharacterFigure(id: id, look: Avatar(config: AvatarPresets.config(for: id)))
                                    .frame(height: 110)
                                    .saturation(open ? 1 : 0)
                                    .opacity(open ? 1 : 0.4)
                                    .overlay(alignment: .topTrailing) {
                                        if !open { Image(systemName: "lock.fill").foregroundStyle(Color.secondaryText).padding(6) }
                                    }
                                Text(PresetAccess.name(id)).font(.subheadline.weight(.semibold)).foregroundStyle(Color.bodyText)
                                Text(open ? "Use this look" : "Complete their journey")
                                    .font(.caption2)
                                    .foregroundStyle(Color.secondaryText)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!open)
                        .accessibilityLabel(open ? "\(PresetAccess.name(id)), use this look" : "\(PresetAccess.name(id)), locked")
                    }
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("Start from a character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.tint(Color.primaryBrown) }
            }
        }
    }
}

#Preview("Part picker") {
    AvatarPartPicker(tab: .hair, config: AvatarPresets.config(for: "david")) { _ in }
        .padding()
}

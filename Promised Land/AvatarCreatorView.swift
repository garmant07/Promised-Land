import SwiftUI
import SwiftData

/// The avatar creator: a large live preview with a gentle idle bob, a tab per part (each a row
/// of rendered thumbnails, with colour swatches beneath), Randomise, Undo, and "Start from a
/// character" (presets unlocked by completing that character's journey). Changes save as you go.
struct AvatarCreatorView: View {
    /// Called by Done. Nil when embedded (onboarding), where there's no Done button.
    var onDone: (() -> Void)?
    var showsName = true

    @Environment(\.modelContext) private var context
    @Query private var profiles: [AvatarProfile]
    @State private var config = AvatarConfig()
    @State private var name = ""
    @State private var history: [AvatarConfig] = []
    @State private var tab: Tab = .skin
    @State private var choosingCharacter = false
    @State private var loaded = false

    enum Tab: String, CaseIterable, Identifiable {
        case skin, hair, beard, head, robe, cloak, item, sandals
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    var body: some View {
        let content = VStack(spacing: 14) {
            preview
            if showsName {
                TextField("Your name", text: $name)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onChange(of: name) { _, new in profile?.name = new }
            }
            actions
            tabs
            AvatarPartPicker(tab: tab, config: config) { change($0) }
        }
        .onAppear(perform: load)
        .sheet(isPresented: $choosingCharacter) {
            CharacterPresetPicker { preset in change(preset); choosingCharacter = false }
        }

        if let onDone {
            NavigationStack {
                ScrollView { content.padding(16) }
                    .themedScreen()
                    .navigationTitle("Your character")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { try? context.save(); onDone() }.tint(Color.primaryBrown)
                        }
                    }
            }
        } else {
            content
        }
    }

    private var profile: AvatarProfile? { profiles.first }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let p = profile ?? AvatarProfile.ensure(in: context)
        config = p.config
        name = p.name
    }

    /// Applies a change (saved straight away), remembering the previous look for Undo.
    private func change(_ new: AvatarConfig) {
        guard new != config else { return }
        history.append(config)
        if history.count > 30 { history.removeFirst() }
        withAnimation(.spring(duration: 0.3)) { config = new }
        profile?.apply(new)
    }

    private var preview: some View {
        TimelineView(.animation) { t in
            let bob = sin(t.date.timeIntervalSinceReferenceDate * 2) * 2.5
            ZStack {
                SandPlot().frame(width: 230, height: 120).offset(y: 92)
                AvatarView(config: config)
                    .frame(width: 140, height: 224)
                    .offset(y: bob)
            }
            .frame(height: 260)
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement()
        .accessibilityLabel("Preview of your character")
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button { change(.random()) } label: { Label("Randomise", systemImage: "dice") }
            Button { choosingCharacter = true } label: { Label("Start from a character", systemImage: "person.2") }
            Button {
                guard let last = history.popLast() else { return }
                withAnimation(.spring(duration: 0.3)) { config = last }
                profile?.apply(last)
            } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
            .disabled(history.isEmpty)
        }
        .buttonStyle(CreatorChipStyle())
    }

    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Tab.allCases) { t in
                    Button(t.title) { tab = t }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tab == t ? Color.onPrimary : Color.primaryBrown)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(tab == t ? Color.primaryBrown : Color.card, in: Capsule())
                        .accessibilityAddTraits(tab == t ? .isSelected : [])
                }
            }
        }
    }
}

/// Small rounded buttons for the creator's actions.
private struct CreatorChipStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(Color.primaryBrown.opacity(isEnabled ? 1 : 0.4))
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.sand.opacity(configuration.isPressed ? 0.6 : 1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    AvatarCreatorView(onDone: {})
        .modelContainer(PreviewData.container)
}

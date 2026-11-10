import SwiftUI

/// The translation in use: the stored choice if it's available, otherwise the first that is.
struct TranslationChoice: DynamicProperty {
    @Environment(\.bibleService) private var service
    @AppStorage(StorageKeys.bibleTranslation) private var stored = BibleTranslation.niv.rawValue

    var current: BibleTranslation? { BibleTranslation.choose(stored: stored, available: service.translations) }
    var available: [BibleTranslation] { service.translations }
    func select(_ t: BibleTranslation) { stored = t.rawValue }
}

/// NIV / NLT / CSB, in the reader's toolbar. Hidden when there's only the bundled sample.
struct TranslationMenu: View {
    private var choice = TranslationChoice()

    var body: some View {
        if choice.available.count > 1, let current = choice.current {
            Menu {
                ForEach(choice.available) { t in
                    Button { choice.select(t) } label: {
                        if t == current { Label(t.name, systemImage: "checkmark") } else { Text(t.name) }
                    }
                }
            } label: {
                Text(current.abbreviation)
                    .font(.footnote.weight(.bold))
                    .padding(.horizontal, 10)
                    .frame(minWidth: 44, minHeight: 32)
                    .background(Color.sand, in: Capsule())
            }
            .tint(Color.primaryBrown)
            .accessibilityLabel("Translation: \(current.name)")
            .accessibilityHint("Choose another translation")
        }
    }
}

/// A chapter that couldn't load: why, Retry when it might help, and whatever else still works
/// (`actions`: "I read this in my own Bible", marking as read).
struct ChapterUnavailableView<Actions: View>: View {
    let title: String
    let error: BibleError
    var retry: () -> Void
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.serifTitle(.largeTitle))
                    .foregroundStyle(Color.bodyText)
                VStack(alignment: .leading, spacing: 10) {
                    Label(error.title, systemImage: error == .offline ? "wifi.slash" : "exclamationmark.circle")
                        .font(.headline)
                        .foregroundStyle(Color.primaryBrown)
                    Text(error.message)
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if error.canRetry {
                        Button { retry() } label: { Label("Retry", systemImage: "arrow.clockwise") }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .cardStyle()
                actions()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

/// Settings → Bible text: the translation, and what isn't on the API plan.
struct BibleTextSettingsSection: View {
    @Environment(\.bibleService) private var service
    private var choice = TranslationChoice()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bible text").font(.serifTitle(.title3)).foregroundStyle(Color.bodyText)
            if !service.isLive {
                Text("Reading shows the bundled American Standard Version sample. Live text needs an API.Bible key (see the README).")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            } else if choice.available.isEmpty {
                Text("Translations load the first time you're online.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            } else {
                Picker("Translation", selection: Binding(get: { choice.current ?? .niv }, set: { choice.select($0) })) {
                    ForEach(choice.available) { t in Text(t.abbreviation).tag(t) }
                }
                .pickerStyle(.segmented)
                if let current = choice.current {
                    Text(current.name).font(.subheadline).foregroundStyle(Color.secondaryText)
                }
                if !service.unavailableTranslations.isEmpty {
                    Text("\(service.unavailableTranslations.map(\.abbreviation).formatted(.list(type: .and))) isn't included in this app's Bible text plan.")
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                }
                Text("Chapters load from API.Bible when you open them and are kept on this device, so you can read them again offline.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .cardStyle()
        .task { await service.prepare() }
    }
}

#if DEBUG
/// DEBUG: API.Bible calls this month against the plan's monthly limit (Settings → Developer).
struct APIUsageBadge: View {
    var usage = APIUsage.shared

    var body: some View {
        let calls = usage.calls()
        Text("API.Bible \(calls) / \(APIUsage.monthlyLimit.formatted()) this month")
            .font(.caption2.monospacedDigit().weight(.bold))
            .foregroundStyle(calls < APIUsage.monthlyLimit * 8 / 10 ? Color.olive : Color.terracotta)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.cream.opacity(0.92), in: Capsule())
            .accessibilityHidden(true)
    }
}
#endif

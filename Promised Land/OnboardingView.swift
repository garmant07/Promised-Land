import SwiftUI
import SwiftData

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var page = 0
    @Environment(\.modelContext) private var context
    @Query private var profiles: [AvatarProfile]
    /// The welcome pages, then the character creator.
    private var pageCount: Int { pages.count + 1 }

    private let pages: [(symbol: String, title: String, text: String)] = [
        ("book.pages.fill", "Read, and the land grows",
         "Every chapter you read lays stones in a world that stretches from Eden to the New Jerusalem."),
        ("map.fill", "Read in any order",
         "Each of the 66 books has a landmark. Start anywhere: fog lifts from a region as soon as you read there."),
        ("sparkles", "Help it flourish",
         "Pass a short quiz to decorate a landmark, and memorise its verse to make it glow. Keep a daily streak going."),
    ]

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: pages[i].symbol)
                            .font(.system(size: 64))
                            .foregroundStyle(Color.terracotta)
                            .frame(width: 140, height: 140)
                            .background(Color.card, in: Circle())
                        Text(pages[i].title)
                            .font(.serifTitle(.largeTitle))
                            .foregroundStyle(Color.bodyText)
                            .multilineTextAlignment(.center)
                        Text(pages[i].text)
                            .font(.body)
                            .foregroundStyle(Color.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .tag(i)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Make your character")
                            .font(.serifTitle(.largeTitle))
                            .foregroundStyle(Color.bodyText)
                        Text("They'll walk your world as you read. You can change this any time.")
                            .foregroundStyle(Color.secondaryText)
                        if let profile = profiles.first {
                            AvatarEditor(profile: profile).padding(.top, 8)
                        } else {
                            ProgressView().frame(maxWidth: .infinity).padding(40)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
                .tag(pages.count)
                .task { AvatarProfile.ensure(in: context) }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page < pageCount - 1 ? "Next" : "Begin the journey") {
                if page < pageCount - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)

            Button("Skip") { withAnimation { page = pageCount - 1 } }
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
                .frame(minHeight: 44)
                .opacity(page < pageCount - 1 ? 1 : 0)
        }
        .padding(.bottom, 16)
        .background(Color.cream.ignoresSafeArea())
    }
}

#Preview {
    OnboardingView(onFinish: {})
        .modelContainer(PreviewData.container)
}

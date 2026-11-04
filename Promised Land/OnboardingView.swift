import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var page = 0

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
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page < pages.count - 1 ? "Next" : "Begin the journey") {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)

            Button("Skip") { onFinish() }
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
                .frame(minHeight: 44)
                .opacity(page < pages.count - 1 ? 1 : 0)
        }
        .padding(.bottom, 16)
        .background(Color.cream.ignoresSafeArea())
    }
}

#Preview {
    OnboardingView(onFinish: {})
}

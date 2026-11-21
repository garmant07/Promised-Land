import SwiftUI

struct PlaceCardRoute: Identifiable {
    let book: Book
    let card: PlaceCard
    let read: Int

    var id: String { book.id }
}

enum PlaceCardShowOnIslandAction: Equatable {
    case showMessage(String)
    case focus
}

func placeCardShowOnIslandAction(read: Int, bookName: String) -> PlaceCardShowOnIslandAction {
    read > 0
        ? .focus
        : .showMessage("You haven't started \(bookName) yet")
}

struct PlaceCardView: View {
    let route: PlaceCardRoute
    let onRead: () -> Void
    let onShowOnIsland: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var unavailableMessage: String?
    @State private var unavailableMessageToken = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .topTrailing) {
                    PlaceTilePicture(book: route.book, faded: false)
                        .aspectRatio(660.0 / 560.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .accessibilityHidden(true)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.primaryBrown)
                            .frame(width: 44, height: 44)
                            .background(Color.cream.opacity(0.9), in: Circle())
                            .contentShape(Circle())
                    }
                    .accessibilityLabel("Close")
                    .padding(10)
                }

                Text(route.card.name)
                    .font(.serifTitle(.largeTitle))
                    .foregroundStyle(Color.bodyText)

                Text("Built by reading \(route.book.name) · \(route.book.chapterCount) chapters")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)

                PlaceCardProgress(read: route.read, total: route.book.chapterCount)

                PlaceCardSection(title: "What it is", text: route.card.what)
                PlaceCardSection(title: "Why it's here", text: route.card.why)

                VStack(spacing: 10) {
                    Button {
                        onRead()
                        dismiss()
                    } label: {
                        Text("Read \(route.book.name)")
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        switch placeCardShowOnIslandAction(read: route.read, bookName: route.book.name) {
                        case .focus:
                            onShowOnIsland()
                            dismiss()
                        case .showMessage(let message):
                            showUnavailableMessage(message)
                        }
                    } label: {
                        Label("Show on my island", systemImage: "mappin.and.ellipse")
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(SoftButtonStyle())
                }
                .overlay(alignment: .top) {
                    if let unavailableMessage {
                        PlaceCardUnavailableMessage(text: unavailableMessage)
                            .offset(y: -38)
                            .transition(.opacity)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .themedScreen()
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.impact(weight: .light), trigger: unavailableMessageToken)
        .animation(reduceMotion ? nil : .easeIn(duration: 0.2), value: unavailableMessage != nil)
        .task(id: unavailableMessageToken) {
            guard unavailableMessageToken > 0 else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            if reduceMotion {
                unavailableMessage = nil
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    unavailableMessage = nil
                }
            }
        }
    }

    private func showUnavailableMessage(_ message: String) {
        unavailableMessageToken += 1
        if reduceMotion {
            unavailableMessage = message
        } else {
            withAnimation(.easeIn(duration: 0.2)) {
                unavailableMessage = message
            }
        }
        AccessibilityNotification.Announcement(message).post()
    }
}

struct PlaceCardUnavailableMessage: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(Color.cream)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primaryBrown, in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct PlaceCardProgress: View {
    let read: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if read > 0 {
                ProgressView(value: Double(min(read, total)), total: Double(total))
                    .tint(Color.olive)
                Text("\(min(read, total)) of \(total) chapters read")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            } else {
                Text("Not started yet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
            }
        }
    }
}

struct PlaceCardSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.serifTitle(.title3))
                .foregroundStyle(Color.bodyText)
            Text(text)
                .font(.body)
                .foregroundStyle(Color.bodyText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    PlaceCardView(
        route: PlaceCardRoute(
            book: BibleCatalog.book(id: "genesis")!,
            card: PlaceCardCatalog.cards[0],
            read: 3),
        onRead: {},
        onShowOnIsland: {})
}

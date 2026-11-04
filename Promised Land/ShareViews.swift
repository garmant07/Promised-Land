import SwiftUI

/// A 9:16 card to share: a picture of your world (or one object), your character and a few stats.
struct ShareCardView: View {
    let title: String
    let subtitle: String
    let artwork: UIImage?
    let avatar: Avatar
    let streak: Int
    let chaptersThisYear: Int

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.bodyText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.terracotta)
            }
            .padding(.top, 34)

            ZStack(alignment: .bottomLeading) {
                Group {
                    if let artwork {
                        Image(uiImage: artwork).resizable().scaledToFill()
                    } else {
                        Color.sand
                    }
                }
                .frame(width: 312, height: 340)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                AvatarFigure(avatar: avatar)
                    .frame(width: 46, height: 84)
                    .padding(14)
                    .background(Color.cream.opacity(0.9), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(12)
            }

            HStack(spacing: 12) {
                stat("\(streak)", streak == 1 ? "day streak" : "day streak", symbol: "flame.fill")
                stat("\(chaptersThisYear)", "chapters this year", symbol: "book.fill")
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill").foregroundStyle(Color.olive)
                Text(avatar.name.isEmpty ? "Promised Land" : "\(avatar.name) · Promised Land")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(.bottom, 26)
        }
        .frame(width: 360, height: 640)
        .background(Color.cream)
    }

    private func stat(_ value: String, _ label: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(Color.terracotta)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.system(size: 22, weight: .semibold, design: .serif)).foregroundStyle(Color.bodyText)
                Text(label).font(.system(size: 12)).foregroundStyle(Color.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Renders the card to an image (1080 × 1920).
    @MainActor
    func render() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// Shows the rendered card with a share button (Instagram Stories, Messages and so on).
struct SharePreviewSheet: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.primaryBrown.opacity(0.15), radius: 12, y: 4)
                    .padding(.horizontal, 28)
                    .accessibilityLabel("Preview of your share image")
                ShareLink(item: Image(uiImage: image),
                          preview: SharePreview("My Promised Land", image: Image(uiImage: image))) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .themedScreen()
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Color.primaryBrown)
                }
            }
        }
    }
}

/// Lets a rendered share image drive `.sheet(item:)`.
struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

#Preview {
    ShareCardView(title: "My Promised Land", subtitle: "12 of 66 places begun", artwork: nil,
                  avatar: .default, streak: 4, chaptersThisYear: 37)
}

import SwiftUI

enum JournalPopupGraphicKind {
    case shelf
    case journal(Color)
    case move(Color)
    case page
    case saveTo(Color)
}

struct JournalPopupHeader: View {
    let title: String
    let hint: String
    let graphic: JournalPopupGraphicKind

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            JournalPopupGraphic(kind: graphic)
                .frame(width: 44, height: 44)
                .background(Color.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.serifTitle(.title2))
                    .foregroundStyle(Color.bodyText)
                    .lineLimit(1)
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

struct JournalPopupGraphic: View {
    let kind: JournalPopupGraphicKind

    var body: some View {
        Group {
            switch kind {
            case .shelf:
                JournalPopupShelfGraphic()
            case .journal(let color):
                JournalPopupSpineGraphic(color: color)
            case .move(let color):
                HStack(spacing: 3) {
                    JournalPopupSpineGraphic(color: color)
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.primaryBrown)
                }
            case .page:
                JournalPopupPageGraphic()
            case .saveTo(let color):
                HStack(spacing: 3) {
                    JournalPopupSpineGraphic(color: color)
                    Image(systemName: "bookmark.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.primaryBrown)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}

struct JournalPopupShelfGraphic: View {
    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .bottom, spacing: 2) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.lavender)
                    .frame(width: 8, height: 22)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.olive)
                    .frame(width: 8, height: 29)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.terracotta)
                    .frame(width: 8, height: 25)
            }
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color.primaryBrown)
                .frame(width: 29, height: 4)
        }
    }
}

struct JournalPopupSpineGraphic: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(color)
            .frame(width: 12, height: 29)
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color.primaryBrown.opacity(0.75))
                    .frame(width: 7, height: 2)
                    .padding(.bottom, 3)
            }
    }
}

struct JournalPopupPageGraphic: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.cream)
                .frame(width: 25, height: 30)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                                .fill(Color.primaryBrown)
                                .frame(width: 15, height: 1.5)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.leading, 5)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(Color.primaryBrown.opacity(0.7), lineWidth: 1)
                }
        }
    }
}

struct JournalPopupBottomButton: View {
    let title: String
    let isDisabled: Bool
    var color: Color = Color.primaryBrown
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.cream)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(color.opacity(isDisabled ? 0.45 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }
}

#Preview("Journal popup graphics") {
    VStack(spacing: 18) {
        HStack(spacing: 18) {
            JournalPopupGraphic(kind: .shelf)
            JournalPopupGraphic(kind: .journal(.lavender))
            JournalPopupGraphic(kind: .move(.olive))
        }
        HStack(spacing: 18) {
            JournalPopupGraphic(kind: .page)
            JournalPopupGraphic(kind: .saveTo(.terracotta))
        }
    }
    .padding(24)
    .background(Color.cream)
}

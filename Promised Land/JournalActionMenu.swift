import SwiftUI

enum JournalActionMenuAction {
    case rename
    case colour
    case moveToShelf
    case deleteShelf
}

struct JournalActionMenu: View {
    let title: String
    let journalColor: Color?
    let actions: [JournalActionMenuAction]
    let onAction: (JournalActionMenuAction) -> Void

    init(title: String, journalColor: Color? = nil, actions: [JournalActionMenuAction], onAction: @escaping (JournalActionMenuAction) -> Void) {
        self.title = title
        self.journalColor = journalColor
        self.actions = actions
        self.onAction = onAction
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(.subheadline, design: .serif).weight(.semibold))
                .foregroundStyle(Color.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

            JournalActionMenuDivider()

            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                if index > 0 {
                    JournalActionMenuDivider()
                }

                JournalActionMenuRow(
                    action: action,
                    journalColor: journalColor,
                    onTap: { onAction(action) }
                )
            }
        }
        .frame(width: 230)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondaryText.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: Color.primaryBrown.opacity(0.16), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

struct JournalActionMenuRow: View {
    let action: JournalActionMenuAction
    let journalColor: Color?
    let onTap: () -> Void

    private var label: String {
        switch action {
        case .rename:
            return "Rename"
        case .colour:
            return "Colour"
        case .moveToShelf:
            return "Move to shelf…"
        case .deleteShelf:
            return "Delete shelf"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 10) {
                JournalActionMenuGraphic(action: action, journalColor: journalColor)
                    .frame(width: 28, height: 28)
                    .background(Color.cream, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .accessibilityHidden(true)

                Text(label)
                    .font(.body)
                    .foregroundStyle(action == .deleteShelf ? Color.terracotta : Color.bodyText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 44, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(JournalActionMenuRowButtonStyle())
        .accessibilityLabel(label)
    }
}

struct JournalActionMenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.primaryBrown.opacity(0.1) : Color.clear)
    }
}

struct JournalActionMenuGraphic: View {
    let action: JournalActionMenuAction
    let journalColor: Color?

    var body: some View {
        switch action {
        case .rename:
            Image(systemName: "pencil")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.primaryBrown)
        case .colour:
            HStack(spacing: 2) {
                Circle().fill(Color.lavender)
                Circle().fill(Color.olive)
                Circle().fill(Color.terracotta)
            }
            .frame(width: 21, height: 7)
        case .moveToShelf:
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(journalColor ?? Color.primaryBrown)
                    .frame(width: 6, height: 15)
                Image(systemName: "arrow.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.primaryBrown)
            }
        case .deleteShelf:
            Image(systemName: "trash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.terracotta)
        }
    }
}

struct JournalActionMenuDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondaryText.opacity(0.2))
            .frame(height: 1 / UIScreen.main.scale)
            .accessibilityHidden(true)
    }
}

struct JournalActionMenuTarget: Identifiable {
    enum Kind {
        case journal(id: UUID, title: String, color: Color)
        case shelf(id: UUID, title: String)
    }

    let id = UUID()
    let kind: Kind
    let anchor: CGRect

    var title: String {
        switch kind {
        case .journal(_, let title, _), .shelf(_, let title):
            return title
        }
    }

    var journalColor: Color? {
        if case .journal(_, _, let color) = kind {
            return color
        }
        return nil
    }

    var actions: [JournalActionMenuAction] {
        switch kind {
        case .journal:
            return [.rename, .colour, .moveToShelf]
        case .shelf:
            return [.rename, .deleteShelf]
        }
    }
}

struct JournalLongPressCapture<Content: View>: View {
    let content: Content
    let onLongPress: (CGRect) -> Void

    var body: some View {
        content
            .overlay {
                GeometryReader { proxy in
                    Color.clear
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 20) {
                            onLongPress(proxy.frame(in: .named("journalPage")))
                        }
                }
            }
    }
}

struct JournalActionMenuOverlay: View {
    let target: JournalActionMenuTarget
    let reduceMotion: Bool
    let onDismiss: () -> Void
    let onAction: (JournalActionMenuAction) -> Void

    @AccessibilityFocusState private var menuIsFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let menuHeight = 62 + CGFloat(target.actions.count) * 60
            let belowY = target.anchor.maxY + 8 + menuHeight / 2
            let aboveY = target.anchor.minY - 8 - menuHeight / 2
            let fitsBelow = belowY + menuHeight / 2 <= proxy.size.height - 12
            let y = min(max(fitsBelow ? belowY : aboveY, 12 + menuHeight / 2),
                        proxy.size.height - 12 - menuHeight / 2)
            let x = min(max(target.anchor.midX, 12 + 115), proxy.size.width - 12 - 115)

            ZStack {
                Color.cream.opacity(0.45)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)

                JournalActionMenu(
                    title: target.title,
                    journalColor: target.journalColor,
                    actions: target.actions,
                    onAction: onAction
                )
                .position(x: x, y: y)
                .transition(.opacity.combined(with: reduceMotion ? .identity : .scale(scale: 0.96)))
                .accessibilityFocused($menuIsFocused)
                .accessibilityAction(.escape, onDismiss)
                .onAppear { menuIsFocused = true }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: target.id)
        }
    }
}

#Preview("Journal action menus") {
    VStack(spacing: 24) {
        JournalActionMenu(
            title: "Morning reflections",
            journalColor: Color.lavender,
            actions: [.rename, .colour, .moveToShelf],
            onAction: { _ in }
        )

        JournalActionMenu(
            title: "My shelves",
            actions: [.rename, .deleteShelf],
            onAction: { _ in }
        )
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.cream)
}

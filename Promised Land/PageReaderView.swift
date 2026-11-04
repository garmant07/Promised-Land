import SwiftUI
import SwiftData

/// A chapter laid out as pages of paper: swipe (or tap the edges) to turn. The last page ends
/// with `footer` (Mark as read and friends). On an iPad held sideways, two pages sit side by side.
struct PageReaderView<Footer: View>: View {
    let title: String
    let verses: [Verse]
    /// Verses with a deep dive get a small sparkle and open it when tapped.
    var deepDive: (Verse) -> DeepDive? = { _ in nil }
    var onDeepDive: (DeepDive, Verse) -> Void = { _, _ in }
    @ViewBuilder var footer: () -> Footer

    @State private var sheet = 0
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let spread = geo.size.width > geo.size.height && geo.size.width >= 700
            let pageWidth = spread ? (geo.size.width - 48) / 2 : geo.size.width - 32
            let pageHeight = max(240, geo.size.height - 56)
            let pages = PagePlanner.pages(verses, width: pageWidth - 48, height: pageHeight - 64,
                                          fontSize: fontSize, footerHeight: 190, titleHeight: 56)
            let sheets: [[Int]] = spread
                ? stride(from: 0, to: pages.count, by: 2).map { [$0] + ($0 + 1 < pages.count ? [$0 + 1] : []) }
                : pages.indices.map { [$0] }

            VStack(spacing: 8) {
                TabView(selection: $sheet) {
                    ForEach(sheets.indices, id: \.self) { s in
                        HStack(spacing: 16) {
                            ForEach(sheets[s], id: \.self) { p in
                                page(p, of: pages, last: p == pages.count - 1)
                                    .frame(width: pageWidth, height: pageHeight)
                            }
                            if spread && sheets[s].count == 1 { Color.clear.frame(width: pageWidth, height: pageHeight) }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(s)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: sheet)

                HStack {
                    Button { sheet = max(0, sheet - 1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .disabled(sheet == 0)
                        .accessibilityLabel("Previous page")
                    Spacer()
                    Text("Page \(min(sheet, sheets.count - 1) + 1) of \(sheets.count)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Color.secondaryText)
                    Spacer()
                    Button { sheet = min(sheets.count - 1, sheet + 1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .disabled(sheet >= sheets.count - 1)
                        .accessibilityLabel("Next page")
                }
                .foregroundStyle(Color.primaryBrown)
                .padding(.horizontal, 16)
                .frame(height: 44)
            }
        }
    }

    private var fontSize: CGFloat {
        switch typeSize {
        case .xSmall, .small: 16
        case .medium, .large: 18
        case .xLarge, .xxLarge: 21
        case .xxxLarge: 24
        default: 27
        }
    }

    private func page(_ index: Int, of pages: [[Verse]], last: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if index == 0 {
                Text(title)
                    .font(.custom("Georgia", size: fontSize * 1.6).weight(.bold))
                    .foregroundStyle(Color.bodyText)
            }
            ForEach(pages[index]) { verse in
                verseLine(verse)
            }
            if last {
                Spacer(minLength: 8)
                footer()
            }
            Spacer(minLength: 0)
            Text("\(index + 1)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Color.secondaryText.opacity(0.7))
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(Paper())
    }

    @ViewBuilder
    private func verseLine(_ verse: Verse) -> some View {
        let number = Text("\(verse.number) ").font(.custom("Georgia", size: fontSize * 0.62).weight(.bold)).foregroundStyle(Color.terracotta)
        let text = Text("\(number)\(verse.text)")
            .font(.custom("Georgia", size: fontSize))
            .foregroundStyle(Color.bodyText)
            .lineSpacing(fontSize * 0.35)
            .fixedSize(horizontal: false, vertical: true)
        if let dive = deepDive(verse) {
            Button { onDeepDive(dive, verse) } label: {
                HStack(alignment: .top, spacing: 4) {
                    text.multilineTextAlignment(.leading)
                    Image(systemName: "sparkle").font(.caption).foregroundStyle(Color.lavender)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens a deep dive on this verse")
        } else {
            text
        }
    }
}

/// A sheet of warm paper with a soft edge and a faint fold shadow.
private struct Paper: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: "#FBF4E4"), Color(hex: "#F6EBD3")], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(alignment: .leading) {
                LinearGradient(colors: [Color.primaryBrown.opacity(0.08), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: Color.primaryBrown.opacity(0.12), radius: 6, x: 0, y: 3)
    }
}

/// Splits verses into pages by estimating how much text fits. Pure, so it's testable.
enum PagePlanner {
    /// Estimated height of a verse at a font size and width.
    static func height(of verse: Verse, width: CGFloat, fontSize: CGFloat) -> CGFloat {
        let charsPerLine = max(10, width / (fontSize * 0.46))
        let lines = ceil(CGFloat(verse.text.count + 4) / charsPerLine)
        return lines * fontSize * 1.38 + 12
    }

    static func pages(_ verses: [Verse], width: CGFloat, height: CGFloat, fontSize: CGFloat,
                      footerHeight: CGFloat, titleHeight: CGFloat) -> [[Verse]] {
        var pages: [[Verse]] = [[]]
        var used = titleHeight
        for verse in verses {
            let h = Self.height(of: verse, width: width, fontSize: fontSize)
            if used + h > height, !pages[pages.count - 1].isEmpty {
                pages.append([])
                used = 0
            }
            pages[pages.count - 1].append(verse)
            used += h
        }
        // Room for "Mark as read" on the last page, or a page of its own.
        if used + footerHeight > height { pages.append([]) }
        return pages
    }
}

// MARK: - Reading check

/// After "Mark as read": a quick check (a question, a short reflection or a journal note)
/// makes the chapter count toward its building. Skipping is fine: the chapter's artifact is
/// already on the island, and the check can be done later from the chapter.
struct ReadingCheckView: View {
    let book: Book
    let chapter: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode?
    @State private var picked: Int?
    @State private var note = ""
    @State private var reflecting = false

    private enum Mode { case question, note }

    private var landmarkName: String { WorldData.landmark(bookID: book.id)?.name ?? book.name }
    private var question: QuizQuestion? {
        guard let quiz = LearningData.forBook(book.id)?.quiz, !quiz.isEmpty else { return nil }
        return quiz[(chapter - 1) % quiz.count]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick check")
                        .font(.serifTitle(.title))
                        .foregroundStyle(Color.bodyText)
                    Text("\(book.name) \(chapter) has placed something on your island. A quick check counts it toward building \(landmarkName).")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)

                    switch mode {
                    case nil: choices
                    case .question: questionView
                    case .note: noteView
                    }

                    Button("Skip for now") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(16)
            }
            .themedScreen()
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $reflecting) {
                ReflectionCard(book: book, chapter: chapter) { finish() }
            }
        }
    }

    private var choices: some View {
        VStack(spacing: 10) {
            if question != nil {
                choice("Answer one question", detail: "A question on \(book.name)", icon: "questionmark.circle") { mode = .question }
            }
            choice("Write a short reflection", detail: "Saved privately in your journal", icon: "text.bubble") { reflecting = true }
            choice("Add a journal note", detail: "A line or two about what you read", icon: "square.and.pencil") { mode = .note }
        }
    }

    private func choice(_ title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.terracotta)
                    .frame(width: 40, height: 40)
                    .background(Color.sand, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(Color.bodyText)
                    Text(detail).font(.footnote).foregroundStyle(Color.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.secondaryText)
            }
            .padding(12)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var questionView: some View {
        if let q = question {
            VStack(alignment: .leading, spacing: 10) {
                Text(q.prompt)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Color.bodyText)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(q.options.indices, id: \.self) { i in
                    let isPicked = picked == i
                    let right = i == q.answerIndex
                    Button {
                        picked = i
                        if right { Task { try? await Task.sleep(for: .milliseconds(700)); finish() } }
                    } label: {
                        HStack {
                            Text(q.options[i]).foregroundStyle(Color.bodyText)
                            Spacer()
                            if isPicked { Image(systemName: right ? "checkmark.circle.fill" : "xmark.circle").foregroundStyle(right ? Color.olive : Color.terracotta) }
                        }
                        .padding(12)
                        .frame(minHeight: 48)
                        .background(isPicked ? (right ? Color.olive.opacity(0.2) : Color.terracotta.opacity(0.15)) : Color.card,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                if let picked, picked != q.answerIndex {
                    Text("Not quite. Have another go.")
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .cardStyle()
        }
    }

    private var noteView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What stayed with you from \(book.name) \(chapter)?")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Color.bodyText)
            TextEditor(text: $note)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel("Journal note")
            Button("Save note") {
                context.insert(JournalEntry(bookID: book.id, chapter: chapter, text: note.trimmingCharacters(in: .whitespacesAndNewlines)))
                try? context.save()
                finish()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .cardStyle()
    }

    private func finish() {
        context.markLatestChecked(book.id, chapter)
        dismiss()
    }
}

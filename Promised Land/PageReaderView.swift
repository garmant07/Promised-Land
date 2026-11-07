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
    /// Called once the last page has been reached (for the reading gate).
    var onReachedEnd: () -> Void = {}
    /// Room kept on the last page for `footer`.
    var footerHeight: CGFloat = 250
    @ViewBuilder var footer: () -> Footer

    @State private var sheet = 0
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let spread = PageReaderLayout.isSpread(geo.size)
            let pageWidth = spread ? (geo.size.width - 48) / 2 : geo.size.width - 32
            let pageHeight = max(240, geo.size.height - 56)
            let pages = PagePlanner.pages(verses, width: pageWidth - 48, height: pageHeight - 64,
                                          fontSize: fontSize, footerHeight: footerHeight, titleHeight: 56, evenCount: spread)
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
                .onAppear {
                    #if DEBUG
                    // "-readerLastPage" turns to the last page on opening (as a swipe would), for checking it.
                    if ProcessInfo.processInfo.arguments.contains("-readerLastPage") { sheet = sheets.count - 1 }
                    #endif
                }
                // Reached the end whenever the last page is showing: on opening, after a swipe, and
                // when the page count changes (a resize can make the page you're on the last one).
                .onChange(of: sheet >= sheets.count - 1, initial: true) { _, last in
                    if last { onReachedEnd() }
                    #if DEBUG
                    print("READER page \(min(sheet, sheets.count - 1) + 1) of \(sheets.count)\(last ? ": last page, reached the end" : "")")
                    #endif
                }

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

extension View {
    /// On iPad, reading opens in a page-sized sheet (wide enough for two pages side by side
    /// when held sideways). No effect on iPhone.
    @ViewBuilder
    func readingSizing(_ reading: Bool) -> some View {
        if reading { presentationSizing(.page) } else { self }
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

/// When two pages sit side by side: a wide, landscape space (an iPad held sideways).
enum PageReaderLayout {
    static func isSpread(_ size: CGSize) -> Bool {
        #if DEBUG
        // "-readerSpread" forces the two-page spread (for checking it without rotating).
        if ProcessInfo.processInfo.arguments.contains("-readerSpread") && size.width >= 700 { return true }
        #endif
        return size.width > size.height && size.width >= 700
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
                      footerHeight: CGFloat, titleHeight: CGFloat, evenCount: Bool = false) -> [[Verse]] {
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
        // In a two-page spread, finish on a full spread: "Mark as read" gets the facing page.
        if evenCount, pages.count % 2 == 1, !(pages.last?.isEmpty ?? true) { pages.append([]) }
        return pages
    }
}

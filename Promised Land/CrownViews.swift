import SwiftUI
import SwiftData

/// Your crowns: one for each full reread of a book.
struct CrownsView: View {
    @ProgressQuery private var progress: GameProgress
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(progress.totalCrownsAvailable) \(progress.totalCrownsAvailable == 1 ? "crown" : "crowns")")
                            .font(.system(size: 40, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.primaryBrown)
                        Text("Each time you read a whole book again, you earn a crown for it.")
                            .foregroundStyle(Color.secondaryText)
                        if progress.cycle > 0 {
                            Text("You've cast your crowns \(progress.cycle) \(progress.cycle == 1 ? "time" : "times"). This is cycle \(progress.cycle + 1).")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                        }
                    }
                    .cardStyle()

                    let earned = BibleCatalog.books.filter { progress.crownsAvailable($0.id) > 0 }
                    if earned.isEmpty {
                        Text("No crowns yet. Finish reading a book, then read it all again.")
                            .foregroundStyle(Color.secondaryText)
                            .cardStyle()
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(earned) { book in
                                VStack(spacing: 6) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 30))
                                        .foregroundStyle(Color.wheat)
                                        .shadow(color: Color.wheat.opacity(0.6), radius: 6)
                                    Text(book.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.bodyText)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                    Text("× \(progress.crownsAvailable(book.id))")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(Color.secondaryText)
                                }
                                .frame(maxWidth: .infinity, minHeight: 104)
                                .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("Crowns")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Color.primaryBrown)
                }
            }
        }
    }
}

/// The throne room at the New Jerusalem: cast your crowns, and a new cycle begins.
struct ThroneRoomView: View {
    @ProgressQuery private var progress: GameProgress
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var casting = false
    @State private var laid = false
    @State private var done = false
    @State private var castCount = 0

    var body: some View {
        let available = progress.totalCrownsAvailable
        let canCast = progress.bibleCompleteThisCycle && available > 0
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [Color.wheat.opacity(0.6), Color.wheat.opacity(0)],
                                                 center: .center, startRadius: 0, endRadius: 130))
                            .frame(width: 260, height: 260)
                        ThroneShapeView()
                            .frame(width: 92, height: 120)
                            .offset(y: -18)
                        // Crowns laid before the throne
                        let shown = min(casting ? castCount : available, 24)
                        ForEach(0..<shown, id: \.self) { i in
                            crown(i, total: shown)
                        }
                    }
                    .frame(height: 280)

                    if ContentGate.isVisible(CrownData.castingVerse) {
                        VStack(spacing: 8) {
                            Text("\u{201C}\(CrownData.castingVerse.text)\u{201D}")
                                .font(.system(.body, design: .serif).italic())
                                .foregroundStyle(Color.bodyText)
                                .multilineTextAlignment(.center)
                            HStack(spacing: 6) {
                                Text(CrownData.castingVerse.reference)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondaryText)
                                DraftBadge(item: CrownData.castingVerse)
                            }
                        }
                    }

                    if done {
                        Text("Your crowns are laid down. A new cycle begins, and everything you've built remains.")
                            .font(.headline)
                            .foregroundStyle(Color.olive)
                            .multilineTextAlignment(.center)
                        Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                    } else if canCast {
                        Text("You've read the whole Bible. You have \(available) \(available == 1 ? "crown" : "crowns") to lay before the throne.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.secondaryText)
                        Button("Cast your crowns") { cast() }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(casting)
                    } else {
                        Text(progress.bibleCompleteThisCycle
                             ? "Read a book through again to earn a crown to lay here."
                             : "Read the whole Bible again to return here and cast the crowns you've earned. You have \(available) so far.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.secondaryText)
                    }
                }
                .padding(20)
            }
            .themedScreen()
            .navigationTitle("Throne Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }.tint(Color.primaryBrown)
                }
            }
        }
    }

    /// Crowns start in an arc below and are carried, one after another, to the foot of the throne.
    private func crown(_ i: Int, total: Int) -> some View {
        let t = total > 1 ? Double(i) / Double(total - 1) : 0.5
        let start = CGSize(width: (t - 0.5) * 260, height: 120 + abs(t - 0.5) * 30)
        let end = CGSize(width: (t - 0.5) * 70, height: 52 + Double(i % 3) * 4)
        return Image(systemName: "crown.fill")
            .font(.system(size: 20))
            .foregroundStyle(Color.wheat)
            .shadow(color: Color.wheat.opacity(0.7), radius: 4)
            .offset(laid ? end : start)
            .scaleEffect(laid ? 0.8 : 1)
            .opacity(done ? 0.9 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.1).delay(Double(i) * 0.12), value: laid)
    }

    private func cast() {
        castCount = progress.totalCrownsAvailable
        casting = true
        withAnimation { laid = true }
        let perBook = Dictionary(uniqueKeysWithValues: BibleCatalog.books.compactMap { book -> (String, Int)? in
            let n = progress.crownsAvailable(book.id)
            return n > 0 ? (book.id, n) : nil
        })
        let cycle = progress.cycle
        let wait = reduceMotion ? 0.3 : 1.1 + Double(min(perBook.values.reduce(0, +), 24)) * 0.12
        Task {
            try? await Task.sleep(for: .seconds(wait))
            context.insert(CrownCasting(cycle: cycle, perBook: perBook))
            try? context.save()
            withAnimation { done = true }
        }
    }
}

/// A simple drawn throne: tall arched back, armrests and steps, in gold and cream.
struct ThroneShapeView: View {
    var body: some View {
        Canvas { c, size in
            let w = size.width, h = size.height
            func rect(_ r: CGRect, _ color: Color, _ radius: CGFloat = 4) {
                c.fill(Path(roundedRect: r, cornerRadius: radius), with: .color(color))
            }
            // Steps
            rect(CGRect(x: 0, y: h * 0.9, width: w, height: h * 0.1), .stoneLight)
            rect(CGRect(x: w * 0.08, y: h * 0.82, width: w * 0.84, height: h * 0.1), .cream)
            // Tall arched back
            let back = Path { p in
                p.move(to: CGPoint(x: w * 0.2, y: h * 0.62))
                p.addLine(to: CGPoint(x: w * 0.2, y: h * 0.2))
                p.addQuadCurve(to: CGPoint(x: w * 0.8, y: h * 0.2), control: CGPoint(x: w * 0.5, y: -h * 0.08))
                p.addLine(to: CGPoint(x: w * 0.8, y: h * 0.62))
                p.closeSubpath()
            }
            c.fill(back, with: .color(.wheat))
            c.fill(Path(ellipseIn: CGRect(x: w * 0.42, y: h * 0.12, width: w * 0.16, height: w * 0.16)), with: .color(.cream))
            // Seat and armrests
            rect(CGRect(x: w * 0.12, y: h * 0.58, width: w * 0.76, height: h * 0.12), Color(hex: "#DDB466"))
            rect(CGRect(x: w * 0.06, y: h * 0.46, width: w * 0.16, height: h * 0.24), .wheat)
            rect(CGRect(x: w * 0.78, y: h * 0.46, width: w * 0.16, height: h * 0.24), Color(hex: "#DDB466"))
            rect(CGRect(x: w * 0.16, y: h * 0.7, width: w * 0.68, height: h * 0.12), .wheat)
        }
        .accessibilityLabel("The throne")
    }
}

#Preview("Crowns") {
    CrownsView().modelContainer(PreviewData.container)
}

#Preview("Throne room") {
    ThroneRoomView().modelContainer(PreviewData.container)
}

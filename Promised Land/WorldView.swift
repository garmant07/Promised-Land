import SwiftUI

struct WorldView: View {
    @ProgressQuery private var progress: GameProgress

    private let columns = 2
    private let rows = 3

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    map
                    placeList
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .themedScreen()
            .navigationTitle("World")
            .hiddenNavigationBar()
            .navigationDestination(for: Place.self) { PlaceDetailView(place: $0) }
            .navigationDestination(for: Book.self) { BookView(book: $0) }
        }
    }

    private var unlockedCount: Int {
        Place.all.filter { progress.level(of: $0) > .locked }.count
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Promised Land")
                .font(.serifTitle(.largeTitle))
                .foregroundStyle(Color.bodyText)
            Text("\(unlockedCount) of \(Place.all.count) places unlocked · \(progress.totalChaptersRead) of \(progress.totalChapters) chapters read")
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
        }
        .padding(.top, 8)
    }

    // MARK: Isometric map

    private var map: some View {
        GeometryReader { geo in
            let tileWidth = min(150, geo.size.width / (CGFloat(columns + rows) / 2))
            let tileHeight = tileWidth / 2
            ZStack(alignment: .topLeading) {
                ForEach(sortedPlaces) { place in
                    let x = CGFloat(place.gridColumn - place.gridRow) * tileWidth / 2 + CGFloat(rows) * tileWidth / 2
                    let y = CGFloat(place.gridColumn + place.gridRow) * tileHeight / 2 + tileWidth / 2
                    NavigationLink(value: place) {
                        PlaceTileView(place: place, level: progress.level(of: place), width: tileWidth)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(place.name), \(progress.level(of: place).title)")
                    .position(x: x + (geo.size.width - tileWidth * CGFloat(columns + rows) / 2) / 2, y: y)
                }
            }
        }
        .aspectRatio(CGFloat(columns + rows) / 2 / 1.85, contentMode: .fit)
        .padding(12)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    /// Back-to-front drawing order so nearer tiles overlap farther ones.
    private var sortedPlaces: [Place] {
        Place.all.sorted { ($0.gridColumn + $0.gridRow, $0.gridColumn) < ($1.gridColumn + $1.gridRow, $1.gridColumn) }
    }

    // MARK: List

    private var placeList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Places")
                .font(.serifTitle(.title3))
                .foregroundStyle(Color.bodyText)
            ForEach(Place.all) { place in
                NavigationLink(value: place) {
                    PlaceRow(place: place, level: progress.level(of: place),
                             chaptersRead: place.book.map(progress.chaptersRead(in:)) ?? 0)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PlaceRow: View {
    let place: Place
    let level: GrowthLevel
    let chaptersRead: Int

    var body: some View {
        HStack(spacing: 14) {
            PlaceTileView(place: place, level: level, width: 64)
                .frame(width: 64, height: 64)
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)
                    .foregroundStyle(Color.bodyText)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer(minLength: 8)
            LevelDots(level: level)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText.opacity(0.6))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .frame(minHeight: 64)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var subtitle: String {
        guard let book = place.book else { return "" }
        if level == .locked { return "Read \(book.name) · \(chaptersRead)/\(book.chapters.count)" }
        return "\(book.name) · \(level.title)"
    }
}

struct LevelDots: View {
    let level: GrowthLevel

    var body: some View {
        HStack(spacing: 5) {
            ForEach(1...3, id: \.self) { i in
                Circle()
                    .fill(i <= level.rawValue ? Color.olive : Color.stoneShade.opacity(0.6))
                    .frame(width: 9, height: 9)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Level \(level.rawValue) of 3")
    }
}

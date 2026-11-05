import CoreGraphics
import Foundation

// The Library: the heart of the island. It physically grows from reading (every chapter adds a
// volume to its shelves) and journaling (every entry or reflection adds notes and small touches).
// Each stage takes up more tiles and stands taller; smaller touches come between stages so it
// changes often. Everything follows from the reading and journal history, so it rebuilds exactly.

/// The Library's big steps, each bigger and taller than the last.
nonisolated enum LibraryStage: Int, CaseIterable, Comparable, Sendable {
    case hut, room, wings, upperFloor, tower, grand

    static func < (a: LibraryStage, b: LibraryStage) -> Bool { a.rawValue < b.rawValue }

    /// Side of its square footprint, in tiles. The grand library is the biggest thing on the island
    /// (the biggest Places are 6 × 6).
    var size: Int { [2, 3, 4, 5, 6, 7][rawValue] }

    /// How tall it stands, relative to the hut.
    var height: CGFloat { [1.0, 1.25, 1.45, 1.9, 2.5, 2.9][rawValue] }

    /// Growth points needed (volumes + 2 × notes).
    var threshold: Int { [0, 12, 50, 150, 400, 900][rawValue] }

    var name: String {
        switch self {
        case .hut: "Reading hut"
        case .room: "Reading room"
        case .wings: "Library with wings"
        case .upperFloor: "Two-storey library"
        case .tower: "Library with a reading tower"
        case .grand: "Grand central library"
        }
    }

    /// What the "see it built" caption says when it grows to this stage.
    var caption: String {
        switch self {
        case .hut: "Your library is a little reading hut"
        case .room: "Your library grew into a bigger reading room"
        case .wings: "Your library added new wings"
        case .upperFloor: "Your library added a second floor"
        case .tower: "Your library added a reading tower"
        case .grand: "Your library became a grand central library"
        }
    }

    var next: LibraryStage? { LibraryStage(rawValue: rawValue + 1) }
}

/// A small addition between stages, earned by volumes (reading) or notes (journaling).
nonisolated enum LibraryTouch: String, CaseIterable, Sendable {
    case bookStack, window, bench, lamp, gardenPath, flowerPots, secondLamp, bookCart, fountain, olives
    case doorNote, writingDesk, noticeBoard, noteGarden, inkwell

    /// Earned by journal notes (otherwise by volumes).
    var byNotes: Bool { [.doorNote, .writingDesk, .noticeBoard, .noteGarden, .inkwell].contains(self) }

    /// Volumes (or notes) needed.
    var needs: Int {
        switch self {
        case .bookStack: 3
        case .window: 8
        case .bench: 20
        case .lamp: 32
        case .gardenPath: 70
        case .flowerPots: 110
        case .secondLamp: 220
        case .bookCart: 320
        case .fountain: 600
        case .olives: 1000
        case .doorNote: 1
        case .writingDesk: 3
        case .noticeBoard: 7
        case .inkwell: 12
        case .noteGarden: 20
        }
    }

    var name: String {
        switch self {
        case .bookStack: "a stack of books by the door"
        case .window: "a new window"
        case .bench: "a reading bench"
        case .lamp: "a lamp"
        case .gardenPath: "a garden path"
        case .flowerPots: "flower pots"
        case .secondLamp: "a second lamp"
        case .bookCart: "a book cart"
        case .fountain: "a fountain"
        case .olives: "olive trees"
        case .doorNote: "a note on the door"
        case .writingDesk: "a writing desk outside"
        case .noticeBoard: "a notice board of your notes"
        case .inkwell: "an inkwell and quill"
        case .noteGarden: "a garden of notes"
        }
    }
}

/// How grown the Library is. Pure, so it's testable.
nonisolated struct LibraryGrowth: Equatable, Sendable {
    /// Distinct chapters read (each is a volume on its shelves).
    let volumes: Int
    /// Journal entries and reflections.
    let notes: Int

    var points: Int { volumes + 2 * notes }

    var stage: LibraryStage { LibraryStage.allCases.last { points >= $0.threshold } ?? .hut }

    var touches: [LibraryTouch] {
        LibraryTouch.allCases.filter { ($0.byNotes ? notes : volumes) >= $0.needs }
    }

    /// 0…1 of the way to the next stage (1 at the grand library).
    var progressToNext: Double {
        guard let next = stage.next else { return 1 }
        let span = Double(next.threshold - stage.threshold)
        return min(1, max(0, Double(points - stage.threshold) / span))
    }

    /// Points still needed for the next stage.
    var pointsToNext: Int? { stage.next.map { max(0, $0.threshold - points) } }

    static let empty = LibraryGrowth(volumes: 0, notes: 0)
}

/// Where the Library stands. Its first spot (the hut) is beside the plaza; as it grows it spreads
/// away from the plaza (towards −x, −y, which is back on screen), from the hut's corner nearest the
/// plaza, so it rises behind the plaza and never covers the starting square. If something you
/// moved yourself is in the way, it shifts along (still covering the hut) or, failing that, stays
/// a size smaller where it does fit, so it never overlaps anything.
nonisolated enum LibraryFootprint {
    /// The square for a stage, anchored at the hut (`hut` = the hut's top-left tile).
    static func rect(hutX: Int, hutY: Int, size: Int, shift: (dx: Int, dy: Int) = (0, 0)) -> (x: Int, y: Int, size: Int) {
        (hutX + 2 - size + shift.dx, hutY + 2 - size + shift.dy, size)
    }

    /// The footprint for `stage`, avoiding `avoid` (tile squares, with a one-tile gap).
    /// - Returns: the square, and the size actually used (smaller than the stage only when boxed in).
    static func place(hutX: Int, hutY: Int, stage: LibraryStage, avoid: [(x: Int, y: Int, size: Int)])
        -> (x: Int, y: Int, size: Int) {
        func clear(_ r: (x: Int, y: Int, size: Int)) -> Bool {
            !avoid.contains { a in
                r.x - 1 < a.x + a.size && a.x < r.x + r.size + 1 && r.y - 1 < a.y + a.size && a.y < r.y + r.size + 1
            }
        }
        var size = stage.size
        while size > 2 {
            // Try the natural spot first, then shifts that still cover the hut, nearest first.
            let room = size - 2
            var shifts: [(dx: Int, dy: Int)] = []
            for dy in 0...room { for dx in 0...room { shifts.append((dx, dy)) } }
            shifts.sort { ($0.dx + $0.dy, $0.dy) < ($1.dx + $1.dy, $1.dy) }
            for s in shifts {
                let r = rect(hutX: hutX, hutY: hutY, size: size, shift: s)
                if clear(r) { return r }
            }
            size -= 1
        }
        return (hutX, hutY, 2)
    }
}

import Foundation
import SwiftData
import CoreGraphics

/// In-memory container with some progress, for SwiftUI previews.
enum PreviewData {
    static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: Schema(AppSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        for chapter in [1, 2] { context.insert(ChapterRead(bookID: "ruth", chapterNumber: chapter)) }
        context.insert(ChapterRead(bookID: "genesis", chapterNumber: 1, date: .now.addingTimeInterval(-86_400)))
        context.insert(ChapterRead(bookID: "john", chapterNumber: 1))
        context.insert(QuizPass(bookID: "ruth", score: 3))
        context.insert(JournalEntry(bookID: "ruth", chapter: 1, prompt: ReflectionData.general[0],
                                    text: "Ruth's loyalty to Naomi, even when it cost her everything."))
        context.insert(JournalEntry(text: "A free entry: thankful for a quiet morning."))
        return container
    }()
}

#if DEBUG
/// DEBUG-only helper so features can be checked in the simulator without tapping.
///
/// Launch arguments (all optional):
///   -resetProgress                       clear all stored progress first
///   -skipOnboarding                      mark onboarding as seen
///   -seed ruth:1-4 genesis:1 john:15*3 quiz:ruth memo:ruth journal:ruth.1   (*3 = read three times)
///   -camera <bookID>                     start the map centred on a landmark
///   -openWorld                           open the world map on launch
///   -openReading <book:chapter>          open reading at a chapter on launch
///   -openStory <id> / -openStats         with -openWorld: open a story card or reading history
///   -openLibrary / -openReflection book:ch   open the journal library or a reflection card
///   -seedAll <n>                         read every chapter n times (crowns, throne room)
enum DebugSeed {
    static func apply(to context: ModelContext) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-resetProgress") {
            context.resetAllProgress()
            UserDefaults.standard.removeObject(forKey: StorageKeys.celebrated)
            UserDefaults.standard.removeObject(forKey: StorageKeys.builtConnections)
            UserDefaults.standard.removeObject(forKey: StorageKeys.worldCamera)
            UserDefaults.standard.removeObject(forKey: StorageKeys.storyObjectsSeen)
            UserDefaults.standard.removeObject(forKey: StorageKeys.libraryRevealed)
            UserDefaults.standard.removeObject(forKey: StorageKeys.journeyStopsSeen)
            UserDefaults.standard.removeObject(forKey: StorageKeys.journeysCompleted)
            UserDefaults.standard.removeObject(forKey: StorageKeys.throneRevealed)
            try? context.delete(model: JournalEntry.self)
        }
        if args.contains("-skipOnboarding") {
            UserDefaults.standard.set(true, forKey: StorageKeys.hasOnboarded)
        }
        // "-seedAll 2" reads every chapter of the Bible twice (for crowns and the throne room).
        if let i = args.firstIndex(of: "-seedAll"), i + 1 < args.count, let times = Int(args[i + 1]) {
            for book in BibleCatalog.books {
                for chapter in book.chapterNumbers {
                    for k in 0..<times {
                        context.insert(ChapterRead(bookID: book.id, chapterNumber: chapter,
                                                   date: .now.addingTimeInterval(-Double(times - k) * 86_400)))
                    }
                }
            }
            try? context.save()
        }
        guard let start = args.firstIndex(of: "-seed") else { return }
        for token in args[(start + 1)...].prefix(while: { !$0.hasPrefix("-") }) {
            let parts = token.split(separator: ":").map(String.init)
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "quiz": context.recordQuizAttempt(parts[1], score: 3, passed: true)
            case "quizfail": context.recordQuizAttempt(parts[1], score: 1, passed: false)
            case "memo": context.recordMemorised(parts[1], reference: "debug")
            case "journal":
                // "journal:ruth.1" adds a sample reflection for Ruth 1.
                let ref = parts[1].split(separator: ".")
                context.insert(JournalEntry(bookID: String(ref[0]), chapter: ref.count > 1 ? Int(ref[1]) : nil,
                                            prompt: ReflectionData.general[0], text: "Sample reflection for testing."))
                try? context.save()
            default:
                // "john:15*3" reads John 15 three times, a day apart (most recent today).
                let spec = parts[1].split(separator: "*")
                let times = spec.count == 2 ? max(1, Int(spec[1]) ?? 1) : 1
                for chapter in chapters(String(spec[0])) {
                    for k in 0..<times {
                        context.recordRead(parts[0], chapter, date: .now.addingTimeInterval(-Double(times - 1 - k) * 86_400))
                    }
                }
            }
        }
    }

    /// `-camera <bookID|gx,gy> [-zoom 1.5]` starts the map at a landmark or grid point.
    static func cameraOverride() -> CameraState? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-camera"), i + 1 < args.count else { return nil }
        let target = args[i + 1]
        var grid: CGPoint?
        if let landmark = WorldData.landmark(bookID: target) {
            grid = landmark.center
        } else {
            let parts = target.split(separator: ",").compactMap { Double($0) }
            if parts.count == 2 { grid = CGPoint(x: parts[0], y: parts[1]) }
        }
        guard let grid else { return nil }
        let zoom = args.firstIndex(of: "-zoom").flatMap { $0 + 1 < args.count ? Double(args[$0 + 1]) : nil } ?? 1.2
        let p = Iso.scene(grid)
        return CameraState(x: p.x, y: p.y, scale: zoom)
    }

    /// Parses "1,2,5-7" into [1, 2, 5, 6, 7].
    private static func chapters(_ spec: String) -> [Int] {
        spec.split(separator: ",").flatMap { piece -> [Int] in
            let bounds = piece.split(separator: "-").compactMap { Int($0) }
            if bounds.count == 2, bounds[0] <= bounds[1] { return Array(bounds[0]...bounds[1]) }
            return bounds.count == 1 ? bounds : []
        }
    }
}
#endif

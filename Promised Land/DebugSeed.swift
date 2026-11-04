import Foundation
import SwiftData
import CoreGraphics

/// In-memory container with some progress, for SwiftUI previews.
enum PreviewData {
    static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: ChapterRead.self, QuizPass.self, VerseMemorised.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        for chapter in [1, 2] { context.insert(ChapterRead(bookID: "ruth", chapterNumber: chapter)) }
        context.insert(ChapterRead(bookID: "genesis", chapterNumber: 1, date: .now.addingTimeInterval(-86_400)))
        context.insert(ChapterRead(bookID: "john", chapterNumber: 1))
        context.insert(QuizPass(bookID: "ruth", score: 3))
        return container
    }()
}

#if DEBUG
/// DEBUG-only helper so features can be checked in the simulator without tapping.
///
/// Launch arguments (all optional):
///   -resetProgress                       clear all stored progress first
///   -skipOnboarding                      mark onboarding as seen
///   -seed ruth:1-4 genesis:1 quiz:ruth memo:ruth
///   -camera <bookID>                     start the map centred on a landmark
///   -openWorld                           open the world map on launch
///   -openReading <book:chapter>          open reading at a chapter on launch
enum DebugSeed {
    static func apply(to context: ModelContext) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-resetProgress") {
            context.resetAllProgress()
            UserDefaults.standard.removeObject(forKey: StorageKeys.celebrated)
            UserDefaults.standard.removeObject(forKey: StorageKeys.builtConnections)
            UserDefaults.standard.removeObject(forKey: StorageKeys.worldCamera)
        }
        if args.contains("-skipOnboarding") {
            UserDefaults.standard.set(true, forKey: StorageKeys.hasOnboarded)
        }
        guard let start = args.firstIndex(of: "-seed") else { return }
        for token in args[(start + 1)...].prefix(while: { !$0.hasPrefix("-") }) {
            let parts = token.split(separator: ":").map(String.init)
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "quiz": context.recordQuizPass(parts[1], score: 3)
            case "memo": context.recordMemorised(parts[1], reference: "debug")
            default:
                for chapter in chapters(parts[1]) { context.markChapter(parts[0], chapter, read: true) }
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

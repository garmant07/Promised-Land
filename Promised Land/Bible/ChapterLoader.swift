import Foundation
import Observation

/// Loads one chapter for the reader through a `BibleService`: loading, the text, or why not
/// (with Retry where it makes sense). Kept apart from the view so it can be tested with a mock.
@MainActor @Observable
final class ChapterLoader {
    enum State: Equatable {
        case loading
        case loaded(ChapterText)
        /// No text for this chapter at all: read it in your own Bible.
        case ownBible
        case failed(BibleError)
    }

    private(set) var state: State = .loading
    /// Bumped by Retry, so a load already under way for an older request is ignored.
    @ObservationIgnored private var generation = 0

    var text: ChapterText? {
        if case .loaded(let text) = state { text } else { nil }
    }

    func load(_ service: any BibleService, bookID: String, chapter: Int, translation: BibleTranslation?) async {
        generation += 1
        let mine = generation
        // Keep showing what's there while switching translation; only a first load shows a spinner.
        if text == nil { state = .loading }
        let next: State
        do {
            next = .loaded(try await service.chapter(bookID: bookID, chapter: chapter, translation: translation))
        } catch BibleError.noText {
            next = .ownBible
        } catch let error as BibleError {
            next = .failed(error)
        } catch {
            next = .failed(.unreadable)
        }
        guard mine == generation else { return }
        state = next
    }
}

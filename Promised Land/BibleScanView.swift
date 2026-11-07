import SwiftUI
import SwiftData
import PhotosUI
import Vision
import UIKit

/// "Use my Bible": take a photo of the page you're reading in your own Bible. Apple's Vision
/// text recognition reads the page heading on this device (nothing is uploaded) to find the book
/// and chapter ("John 15, got it"). Read it in your Bible, tap "Mark complete", and answer the same
/// quick question. If the photo can't be read, pick the chapter yourself and go straight to the
/// question. You can keep the photo with your journal entry (stored only on this device).
struct BibleScanView: View {
    /// The chapter you were looking at, if any (used when picking by hand).
    var suggested: ChapterRef?
    var onDone: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StorageKeys.readingStrictness) private var strictnessRaw = ""
    @AppStorage(StorageKeys.ageGroup) private var ageGroup = ""
    @ProgressQuery private var progress: GameProgress
    @Environment(\.bibleService) private var bible
    private var translation = TranslationChoice()

    @State private var phase: Phase = .capture
    @State private var image: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var keepPhoto = false
    @State private var manualBook = "john"
    @State private var manualChapter = 1
    @State private var readingSince = Date.now
    @State private var asking: ChapterRef?

    private enum Phase: Equatable {
        case capture, reading, notFound, manual
        case found(ChapterRef)
    }

    private var strictness: ReadingStrictness { .current(stored: strictnessRaw, ageGroup: ageGroup) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch phase {
                    case .capture: captureCard
                    case .reading: ProgressView("Reading the page…").frame(maxWidth: .infinity).padding(40)
                    case .notFound: notFoundCard
                    case .manual: manualCard
                    case .found(let ref): foundCard(ref)
                    }
                    if let image {
                        Image(uiImage: image)
                            .resizable().scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("Your photo of the page")
                    }
                }
                .padding(16)
            }
            .themedScreen()
            .navigationTitle("Use my Bible")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.tint(Color.primaryBrown) }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) { await read(ui) }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { ui in
                    showingCamera = false
                    if let ui { Task { await read(ui) } }
                }
                .ignoresSafeArea()
            }
            .sheet(item: $asking) { ref in
                if let book = BibleCatalog.book(id: ref.bookID) {
                    ReadingQuestionView(book: book, chapter: ref.chapter, onCounted: { counted(ref) }, onLookAgain: { asking = nil })
                }
            }
            .onAppear {
                if let suggested { manualBook = suggested.bookID; manualChapter = suggested.chapter }
            }
        }
    }

    // MARK: Steps

    private var captureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Take a photo of the top of the page, where the book and chapter are printed.")
                .foregroundStyle(Color.bodyText)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { showingCamera = true } label: { Label("Take a photo", systemImage: "camera.fill") }
                    .buttonStyle(PrimaryButtonStyle())
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose a photo", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(SoftButtonStyle())
            Button("Pick the chapter myself") { phase = .manual }
                .buttonStyle(SoftButtonStyle())
            Label("The photo is read on this device and never uploaded.", systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
        }
        .cardStyle()
    }

    private var notFoundCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Couldn't read the chapter from that photo", systemImage: "exclamationmark.magnifyingglass")
                .font(.headline)
                .foregroundStyle(Color.primaryBrown)
            Text("Good light and the page heading in view help. Small print and two-page chapters can be tricky.")
                .font(.subheadline)
                .foregroundStyle(Color.secondaryText)
            Button("Try another photo") { phase = .capture; image = nil; pickerItem = nil }
                .buttonStyle(SoftButtonStyle())
            Button("Pick the chapter myself") { phase = .manual }
                .buttonStyle(PrimaryButtonStyle())
        }
        .cardStyle()
    }

    private var manualCard: some View {
        let book = BibleCatalog.book(id: manualBook)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Which chapter did you read?").font(.headline).foregroundStyle(Color.bodyText)
            Picker("Book", selection: $manualBook) {
                ForEach(BibleCatalog.books) { Text($0.name).tag($0.id) }
            }
            .pickerStyle(.menu)
            .tint(Color.primaryBrown)
            .onChange(of: manualBook) { _, _ in manualChapter = 1 }
            Stepper("Chapter \(manualChapter)", value: $manualChapter, in: 1...(book?.chapterCount ?? 1))
                .frame(minHeight: 44)
            Button("Answer the question") { asking = ChapterRef(bookID: manualBook, chapter: manualChapter) }
                .buttonStyle(PrimaryButtonStyle())
        }
        .cardStyle()
    }

    private func foundCard(_ ref: ChapterRef) -> some View {
        let name = BibleCatalog.book(id: ref.bookID)?.name ?? ref.bookID
        let timed = ReadingGate.timerApplies(strictness: strictness, ownBible: true)
        let required = timed ? ReadingGate.minimumSeconds(words: ReadingGate.words(bookID: ref.bookID, chapter: ref.chapter, service: bible,
                                                                                         translation: translation.current),
                                                                 strictness: strictness) : 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("\(name) \(ref.chapter), got it", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.olive)
                Spacer()
                Button("Change") { manualBook = ref.bookID; manualChapter = ref.chapter; phase = .manual }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primaryBrown)
                    .frame(minHeight: 44)
            }
            Text("Read \(name) \(ref.chapter) in your Bible, then tap \u{201C}\(FinishButton.title(readBefore: progress.isRead(ref.bookID, chapter: ref.chapter)))\u{201D}.")
                .foregroundStyle(Color.bodyText)
            Toggle("Keep this photo with my journal", isOn: $keepPhoto)
                .tint(Color.olive)
                .frame(minHeight: 44)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = context.date.timeIntervalSince(readingSince)
                FinishButton(progress: ReadingGate.progress(reachedEnd: true, elapsed: elapsed, required: required),
                             enabled: ReadingGate.canFinish(reachedEnd: true, elapsed: elapsed, required: required),
                             readBefore: progress.isRead(ref.bookID, chapter: ref.chapter)) { asking = ref }
            }
        }
        .cardStyle()
    }

    // MARK: Work

    private func read(_ ui: UIImage) async {
        let upright = ui.upright(maxSide: 2000)
        image = upright
        phase = .reading
        let lines = await PageText.lines(in: upright)
        if let match = ChapterDetector.detect(lines) {
            readingSince = .now
            phase = .found(ChapterRef(bookID: match.bookID, chapter: match.chapter))
        } else {
            phase = .notFound
        }
    }

    private func counted(_ ref: ChapterRef) {
        context.recordRead(ref.bookID, ref.chapter, checked: true)
        if keepPhoto, let data = image?.upright(maxSide: 1600).jpegData(compressionQuality: 0.6) {
            let entry = JournalEntry(bookID: ref.bookID, chapter: ref.chapter, text: "Read in my own Bible.")
            context.insert(entry)
            context.insert(ReadingPhoto(bookID: ref.bookID, chapter: ref.chapter, imageData: data, journalEntryID: entry.id))
            try? context.save()
        }
        asking = nil
        onDone()
    }
}

/// Text on a photo, read on this device with Apple's Vision framework, top lines first.
enum PageText {
    static func lines(in image: UIImage) async -> [String] {
        guard let cg = image.cgImage else { return [] }
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        guard let observations = try? await request.perform(on: cg) else { return [] }
        return observations
            .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y } // Vision's y runs up from the bottom
            .compactMap { $0.topCandidates(1).first?.string }
    }
}

extension UIImage {
    /// Drawn upright (so Vision sees it the right way round), no bigger than `maxSide` points.
    func upright(maxSide: CGFloat) -> UIImage {
        let k = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: (size.width * k).rounded(), height: (size.height * k).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}

/// The system camera, for a photo of a page.
struct CameraPicker: UIViewControllerRepresentable {
    var onPicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPicked: (UIImage?) -> Void
        init(onPicked: @escaping (UIImage?) -> Void) { self.onPicked = onPicked }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onPicked(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onPicked(nil) }
    }
}

#Preview {
    BibleScanView(suggested: ChapterRef(bookID: "john", chapter: 15)) {}
        .modelContainer(PreviewData.container)
}

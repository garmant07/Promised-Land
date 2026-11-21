nonisolated struct PlaceFocusState: Equatable, Sendable {
    private(set) var pendingBookID: String?
    private(set) var activeBookID: String?

    mutating func request(_ bookID: String) {
        pendingBookID = bookID
    }

    mutating func begin(isAvailable: Bool) {
        guard let pendingBookID else { return }
        self.pendingBookID = nil
        activeBookID = isAvailable ? pendingBookID : nil
    }

    mutating func consume() {
        activeBookID = nil
    }
}

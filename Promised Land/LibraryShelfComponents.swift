import SwiftUI

/// The warm background shared by the Library hub and its journal shelves.
struct LibraryBackdrop: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: "#F6EAD4"), Color(hex: "#EFDDBE")],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// A wooden shelf board shared by Library pages.
struct LibraryPlank: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: "#CFA474"), Color(hex: "#B98A5C")],
                                 startPoint: .top, endPoint: .bottom))
            .frame(height: 12)
            .shadow(color: Color.primaryBrown.opacity(0.22), radius: 3, y: 3)
    }
}

/// A consistent serif label above a Library shelf.
struct LibraryShelfLabel: View {
    let title: String
    let systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.terracotta)
            }
            Text(title)
                .font(.serifTitle(.title3))
                .foregroundStyle(Color.bodyText)
        }
    }
}

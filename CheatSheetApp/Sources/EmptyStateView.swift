import SwiftUI

struct EmptyStateView: View {
    let addAction: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Note Selected", systemImage: "note.text.badge.plus")
        } description: {
            Text("Create a small checklist or cheat sheet to keep nearby.")
        } actions: {
            Button("Create Note", systemImage: "plus", action: addAction)
                .glassCompatibleButtonStyle(prominent: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

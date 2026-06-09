import SwiftUI

struct EditorHeader: View {
    @Binding var note: CheatSheetNote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $note.title)
                .font(.title)
                .textFieldStyle(.plain)
                .foregroundStyle(.primary)

            Label(note.isPinned ? "Shown on desktop widget" : "Editable note", systemImage: note.isPinned ? "pin.fill" : "text.alignleft")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

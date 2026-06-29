import SwiftUI

struct EditorHeader: View {
    @Binding var note: CheatSheetNote
    let pinAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Title", text: $note.title)
                .font(.title)
                .textFieldStyle(.plain)
                .foregroundStyle(.primary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    statusLabel

                    Spacer(minLength: 8)

                    compactControls
                }

                VStack(alignment: .leading, spacing: 8) {
                    statusLabel
                    compactControls
                }
            }
        }
    }

    private var statusLabel: some View {
        Label(note.isPinned ? "Shown in widget" : "Editable note", systemImage: note.isPinned ? "pin.fill" : "text.alignleft")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var compactControls: some View {
        HStack(spacing: 8) {
            GlassPalettePicker(selection: $note.tintHex)

            FontStylePicker(selection: $note.fontStyle)

            Button(action: pinAction) {
                Label(note.isPinned ? "Pinned to Widget" : "Use in Widget", systemImage: note.isPinned ? "pin.fill" : "pin")
            }
            .labelStyle(.iconOnly)
            .controlSize(.small)
            .glassCompatibleButtonStyle(prominent: note.isPinned)
            .help(note.isPinned ? "This note appears in the widget" : "Show this note in the widget")
            .accessibilityLabel(note.isPinned ? "Pinned to Widget" : "Use in Widget")
        }
    }
}

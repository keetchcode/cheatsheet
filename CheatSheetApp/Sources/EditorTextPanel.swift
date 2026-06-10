import SwiftUI

struct EditorTextPanel: View {
    @Binding var note: CheatSheetNote
    let pinAction: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            EditorHeader(note: $note, pinAction: pinAction)

            TextEditor(text: $note.body)
                .font(.system(.body, design: note.fontStyle.design))
                .lineSpacing(5)
                .scrollContentBackground(.hidden)
                .padding(18)
                .liquidGlassPanel(tint: Color(hex: note.tintHex), cornerRadius: 22)
        }
    }
}

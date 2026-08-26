import SwiftUI

struct EditorTextPanel: View {
    @Binding var note: CheatSheetNote
    let pinAction: () -> Void

    var body: some View {
        VStack(spacing: AppDesign.editorSectionSpacing) {
            EditorHeader(note: $note, pinAction: pinAction)

            TextEditor(text: $note.body)
                .accessibilityIdentifier("note-body-editor")
                .font(.system(.body, design: note.fontStyle.design))
                .lineSpacing(5)
                .scrollContentBackground(.hidden)
                .padding(AppDesign.editorTextPadding)
                .noteContentSurface(tint: Color(hex: note.tintHex), cornerRadius: AppDesign.editorCornerRadius)
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
        }
    }
}

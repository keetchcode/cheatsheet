import SwiftUI

struct EditorTextPanel: View {
    @Binding var note: CheatSheetNote
    let pinAction: () -> Void

    var body: some View {
        VStack(spacing: AppDesign.editorSectionSpacing) {
            EditorHeader(note: $note, pinAction: pinAction)

            TextEditor(text: $note.body)
                .font(.system(.body, design: note.fontStyle.design))
                .lineSpacing(5)
                .scrollContentBackground(.hidden)
                .padding(AppDesign.editorTextPadding)
                .editorPanelSurface(tint: Color(hex: note.tintHex))
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
        }
    }
}

private extension View {
    @ViewBuilder
    func editorPanelSurface(tint: Color) -> some View {
        #if os(iOS)
        self
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: AppDesign.editorCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.editorCornerRadius, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.16), lineWidth: 1)
            }
        #else
        self.liquidGlassPanel(tint: tint, cornerRadius: AppDesign.editorCornerRadius)
        #endif
    }
}

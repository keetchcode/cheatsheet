import SwiftUI

struct EditorView: View {
    @Binding var note: CheatSheetNote
    let pinAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppDesign.panelSpacing) {
            EditorTextPanel(note: $note)
                .frame(minWidth: AppDesign.editorMinimumWidth)

            VStack(spacing: AppDesign.panelSpacing) {
                EditorInspectorView(note: $note, pinAction: pinAction)

                Button("Delete Note", systemImage: "trash", role: .destructive, action: deleteAction)
                    .frame(maxWidth: .infinity)
                    .glassCompatibleButtonStyle()
                    .help("Delete selected note")
            }
            .frame(width: AppDesign.inspectorIdealWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

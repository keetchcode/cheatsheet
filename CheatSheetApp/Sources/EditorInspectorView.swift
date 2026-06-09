import SwiftUI

struct EditorInspectorView: View {
    @Binding var note: CheatSheetNote
    let pinAction: () -> Void

    var body: some View {
        LiquidGlassGroup(spacing: AppDesign.panelSpacing) {
            VStack(spacing: AppDesign.panelSpacing) {
                StickyNotePreview(note: note)
                    .frame(minWidth: AppDesign.inspectorMinimumWidth)

                NoteLookPanel(note: $note, pinAction: pinAction)
                    .frame(minWidth: AppDesign.inspectorMinimumWidth)
            }
        }
    }
}

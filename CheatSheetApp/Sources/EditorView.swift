import SwiftUI

struct EditorView: View {
    @Binding var note: CheatSheetNote
    let pinAction: () -> Void

    var body: some View {
        EditorTextPanel(note: $note, pinAction: pinAction)
            .frame(minWidth: AppDesign.editorMinimumWidthForCurrentPlatform)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

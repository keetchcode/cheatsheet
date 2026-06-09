import SwiftUI

struct NoteLookPanel: View {
    @Binding var note: CheatSheetNote
    let pinAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Look", systemImage: "paintpalette")
                    .font(.headline)

                Spacer()

                Text(note.isPinned ? "Widget note" : "Local note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                GlassPalettePicker(selection: $note.tintHex)
            }

            LabeledContent("Font") {
                FontStylePicker(selection: $note.fontStyle)
                    .frame(minWidth: 132)
            }

            if note.isPinned {
                Button("Pinned to Widget", systemImage: "pin.fill", action: pinAction)
                    .frame(maxWidth: .infinity)
                    .glassCompatibleButtonStyle(prominent: true)
                    .help("This note appears on the desktop widget")
            } else {
                Button("Use in Widget", systemImage: "pin", action: pinAction)
                    .frame(maxWidth: .infinity)
                    .glassCompatibleButtonStyle()
                    .help("Show this note on the desktop widget")
            }
        }
        .padding(AppDesign.panelPadding)
        .liquidGlassPanel(tint: Color(hex: note.tintHex), cornerRadius: 20)
    }
}

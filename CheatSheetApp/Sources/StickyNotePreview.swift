import SwiftUI

struct StickyNotePreview: View {
    let note: CheatSheetNote

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.panelSpacing) {
            HStack(spacing: 10) {
                Image(systemName: "text.page.fill")
                    .font(.title3)
                    .foregroundStyle(Color(hex: note.tintHex))
                    .accessibilityHidden(true)

                Text(note.displayTitle)
                    .font(.system(.title2, design: note.fontStyle.design))
                    .lineLimit(2)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 9) {
                ForEach(note.displayLines.prefix(9)) { line in
                    ChecklistLineView(
                        text: line.text,
                        isTask: line.isTask,
                        isComplete: line.isComplete,
                        isHeading: line.isHeading,
                        fontDesign: note.fontStyle.design
                    )
                }
            }

            Spacer(minLength: 0)

            Text(note.updatedAt.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .aspectRatio(1.08, contentMode: .fit)
        .liquidGlassPanel(tint: Color(hex: note.tintHex), cornerRadius: AppDesign.previewCornerRadius)
        .accessibilityElement(children: .combine)
    }
}

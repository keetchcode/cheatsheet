import SwiftUI

struct SidebarNoteRow: View {
    let note: CheatSheetNote

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: note.tintHex))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(note.displayTitle)
                        .font(.callout)
                        .lineLimit(1)

                    if note.isArchived {
                        Image(systemName: "archivebox.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("In Trash")
                    } else if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Pinned")
                    }
                }

                Text(note.isArchived ? note.trashStatusText : note.previewLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }
}

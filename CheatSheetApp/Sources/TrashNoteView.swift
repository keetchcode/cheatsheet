import SwiftUI

struct TrashNoteView: View {
    let note: CheatSheetNote
    let backAction: () -> Void
    let restoreAction: () -> Void
    let deleteNowAction: () -> Void
    @State private var isConfirmingPermanentDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.panelSpacing) {
            Button("Back to Notes", systemImage: "chevron.left", action: backAction)
                .controlSize(.small)
                .glassCompatibleButtonStyle()
                .help("Return to active notes")

            VStack(alignment: .leading, spacing: AppDesign.panelSpacing) {
                Label("In Trash", systemImage: "archivebox")
                    .font(.title2)
                    .bold()

                Text(note.trashStatusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(note.displayTitle)
                        .font(.headline)

                    Text(note.previewLine)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                ViewThatFits(in: .horizontal) {
                    HStack {
                        restoreButton
                        deleteNowButton
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        restoreButton
                        deleteNowButton
                    }
                }
            }
            .padding(AppDesign.panelPadding)
            .noteContentSurface(tint: Color(hex: note.tintHex), cornerRadius: 20)
            .frame(maxWidth: 420, alignment: .leading)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog("Delete this note permanently?", isPresented: $isConfirmingPermanentDelete) {
            Button("Delete Now", role: .destructive, action: deleteNowAction)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var restoreButton: some View {
        Button("Restore Note", systemImage: "arrow.uturn.backward", action: restoreAction)
            .glassCompatibleButtonStyle(prominent: true)
            .accessibilityIdentifier("restore-note-button")
    }

    private var deleteNowButton: some View {
        Button("Delete Now", systemImage: "xmark.circle", role: .destructive) {
            isConfirmingPermanentDelete = true
        }
        .glassCompatibleButtonStyle()
        .accessibilityIdentifier("delete-note-button")
    }
}

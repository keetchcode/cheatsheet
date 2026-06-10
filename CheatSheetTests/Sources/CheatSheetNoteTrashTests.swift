import Foundation
import Testing

struct CheatSheetNoteTrashTests {
    @Test func statusTextRoundsUpRemainingDays() {
        let archivedAt = Date(timeIntervalSince1970: 1_000)
        let note = CheatSheetNote(title: "Archived", body: "- demo", archivedAt: archivedAt)

        #expect(note.trashStatusText(referenceDate: archivedAt) == "Deletes automatically in 30 days.")
        #expect(
            note.trashStatusText(
                referenceDate: archivedAt.addingTimeInterval(29 * NoteTrashPolicy.dayInterval + 1)
            ) == "Deletes automatically in 1 day."
        )
        #expect(
            note.trashStatusText(
                referenceDate: archivedAt.addingTimeInterval(NoteTrashPolicy.retentionInterval)
            ) == "This note is ready for permanent deletion."
        )
    }
}

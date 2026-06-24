import Foundation
import Testing

struct WidgetNoteSelectionTests {
    @Test func selectsPinnedActiveNoteForWidget() throws {
        let first = Self.note(id: "00000000-0000-0000-0000-000000001001", title: "First")
        let pinned = Self.note(id: "00000000-0000-0000-0000-000000001002", title: "Pinned", isPinned: true)

        let selected = try #require([first, pinned].widgetDisplayNote)

        #expect(selected.id == pinned.id)
    }

    @Test func skipsArchivedPinnedNoteForWidget() throws {
        let archivedPinned = Self.note(
            id: "00000000-0000-0000-0000-000000001101",
            title: "Archived Pinned",
            isPinned: true,
            archivedAt: Date(timeIntervalSince1970: 10)
        )
        let active = Self.note(id: "00000000-0000-0000-0000-000000001102", title: "Active")

        let selected = try #require([archivedPinned, active].widgetDisplayNote)

        #expect(selected.id == active.id)
    }

    @Test func returnsNilWhenOnlyArchivedNotesExist() {
        let archived = Self.note(
            id: "00000000-0000-0000-0000-000000001201",
            title: "Archived",
            archivedAt: Date(timeIntervalSince1970: 10)
        )

        #expect([archived].widgetDisplayNote == nil)
    }

    private static func note(
        id: String,
        title: String,
        isPinned: Bool = false,
        archivedAt: Date? = nil
    ) -> CheatSheetNote {
        CheatSheetNote(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            body: "- \(title)",
            isPinned: isPinned,
            updatedAt: Date(timeIntervalSince1970: 1),
            archivedAt: archivedAt
        )
    }
}

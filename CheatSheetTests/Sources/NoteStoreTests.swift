import Foundation
import Testing

@MainActor
struct NoteStoreTests {
    @Test func initializesWithPinnedNoteSelected() throws {
        let pinnedID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000101"))
        let unpinnedID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000102"))
        let repository = SpyNoteRepository(
            loadedNotes: [
                CheatSheetNote(id: unpinnedID, title: "Local", body: "- local"),
                CheatSheetNote(id: pinnedID, title: "Pinned", body: "- pinned", isPinned: true)
            ]
        )

        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {})

        #expect(sut.selectedNoteID == pinnedID)
        #expect(sut.selectedNote?.title == "Pinned")
    }

    @Test func addNoteInsertsAndSelectsNewNote() {
        let repository = SpyNoteRepository(loadedNotes: [Self.sampleNote(title: "Existing")])
        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {})

        sut.addNote()

        #expect(sut.notes.count == 2)
        #expect(sut.notes.first?.title == "New Cheat Sheet")
        #expect(sut.selectedNoteID == sut.notes.first?.id)
    }

    @Test func deleteSelectedNoteKeepsAtLeastOneNote() {
        let first = Self.sampleNote(title: "First")
        let repository = SpyNoteRepository(loadedNotes: [first])
        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {})

        sut.deleteSelectedNote()

        #expect(sut.notes == [first])
        #expect(sut.selectedNoteID == first.id)
    }

    @Test func setPinnedClearsOtherPinnedNotes() throws {
        let firstID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000201"))
        let secondID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000202"))
        let repository = SpyNoteRepository(
            loadedNotes: [
                CheatSheetNote(id: firstID, title: "First", body: "- first", isPinned: true),
                CheatSheetNote(id: secondID, title: "Second", body: "- second")
            ]
        )
        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {})

        sut.setPinned(secondID)

        #expect(sut.notes.first { $0.id == firstID }?.isPinned == false)
        #expect(sut.notes.first { $0.id == secondID }?.isPinned == true)
        #expect(sut.selectedNoteID == secondID)
    }

    @Test func bindingWritesByNoteIDAfterArrayChanges() throws {
        let firstID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000301"))
        let secondID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000302"))
        let repository = SpyNoteRepository(
            loadedNotes: [
                CheatSheetNote(id: firstID, title: "First", body: "- first"),
                CheatSheetNote(id: secondID, title: "Second", body: "- second")
            ]
        )
        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {})
        let binding = try #require(sut.binding(for: secondID))

        sut.addNote()
        var updated = binding.wrappedValue
        updated.title = "Updated Second"
        binding.wrappedValue = updated

        #expect(sut.notes.first { $0.id == secondID }?.title == "Updated Second")
        #expect(sut.notes.first { $0.id == firstID }?.title == "First")
    }

    @Test func editingNoteDoesNotMoveItToTopOfSidebar() throws {
        let firstID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000501"))
        let secondID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000502"))
        let repository = SpyNoteRepository(
            loadedNotes: [
                CheatSheetNote(id: firstID, title: "First", body: "- first", updatedAt: Date(timeIntervalSince1970: 1)),
                CheatSheetNote(id: secondID, title: "Second", body: "- second", updatedAt: Date(timeIntervalSince1970: 2))
            ]
        )
        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {})
        let binding = try #require(sut.binding(for: secondID))
        var updated = binding.wrappedValue
        updated.body = "- edited second"

        binding.wrappedValue = updated

        #expect(sut.sortedNotes.map(\.id) == [firstID, secondID])
        #expect(sut.notes.first { $0.id == secondID }?.body == "- edited second")
    }

    @Test func flushPendingChangesSavesAndReloadsWidget() {
        let repository = SpyNoteRepository(loadedNotes: [Self.sampleNote(title: "Existing")])
        var reloadCount = 0
        let sut = NoteStore(repository: repository) {
            reloadCount += 1
        }
        reloadCount = 0

        sut.addNote()
        sut.flushPendingChanges()

        #expect(repository.savedNotes.last == sut.notes)
        #expect(reloadCount == 1)
    }

    @Test func flushPendingChangesSkipsWidgetReloadForNonWidgetNoteChanges() throws {
        let pinnedID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000401"))
        let unpinnedID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000402"))
        let repository = SpyNoteRepository(
            loadedNotes: [
                Self.sampleNote(id: pinnedID, title: "Pinned", isPinned: true),
                Self.sampleNote(id: unpinnedID, title: "Draft")
            ]
        )
        var reloadCount = 0
        let sut = NoteStore(repository: repository) {
            reloadCount += 1
        }
        reloadCount = 0
        let draftBinding = try #require(sut.binding(for: unpinnedID))
        var draft = draftBinding.wrappedValue
        draft.body = "- edited draft"

        draftBinding.wrappedValue = draft
        sut.flushPendingChanges()

        #expect(repository.savedNotes.last == sut.notes)
        #expect(reloadCount == 0)
    }

    private static func sampleNote(
        id: UUID = UUID(),
        title: String,
        isPinned: Bool = false
    ) -> CheatSheetNote {
        CheatSheetNote(
            id: id,
            title: title,
            body: "- \(title)",
            isPinned: isPinned,
            updatedAt: Date(timeIntervalSince1970: 1)
        )
    }
}

private final class SpyNoteRepository: CheatSheetNoteRepository {
    let loadedNotes: [CheatSheetNote]
    private(set) var savedNotes: [[CheatSheetNote]] = []

    init(loadedNotes: [CheatSheetNote]) {
        self.loadedNotes = loadedNotes
    }

    func loadNotes() -> [CheatSheetNote] {
        loadedNotes
    }

    func saveNotes(_ notes: [CheatSheetNote]) {
        savedNotes.append(notes)
    }
}

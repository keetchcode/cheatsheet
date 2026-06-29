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

        let noteID = sut.addNote()

        #expect(sut.notes.count == 2)
        #expect(sut.notes.first?.title == "New Cheat Sheet")
        #expect(sut.selectedNoteID == noteID)
        #expect(sut.notes.first?.id == noteID)
    }

    @Test func addNoteSupportsCustomQuickCaptureContent() {
        let repository = SpyNoteRepository(loadedNotes: [])
        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {})

        let noteID = sut.addNote(
            title: "Docker Cleanup",
            body: "# Docker Cleanup\n- docker system prune",
            tintHex: CheatSheetPalette.cyan.rawValue
        )

        #expect(sut.notes.first?.id == noteID)
        #expect(sut.notes.first?.title == "Docker Cleanup")
        #expect(sut.notes.first?.body == "# Docker Cleanup\n- docker system prune")
        #expect(sut.notes.first?.tintHex == CheatSheetPalette.cyan.rawValue)
        #expect(sut.selectedNoteID == noteID)
    }

    @Test func noteWithIDReturnsMatchingNote() throws {
        let noteID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000103"))
        let repository = SpyNoteRepository(
            loadedNotes: [
                Self.sampleNote(id: noteID, title: "Find Me"),
                Self.sampleNote(title: "Other")
            ]
        )
        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {})

        #expect(sut.note(with: noteID)?.title == "Find Me")
    }

    @Test func archiveSelectedNoteMovesItToTrashAndSelectsNextActiveNote() throws {
        let firstID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000601"))
        let secondID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000602"))
        let archiveDate = Date(timeIntervalSince1970: 100)
        let repository = SpyNoteRepository(
            loadedNotes: [
                Self.sampleNote(id: firstID, title: "First", isPinned: true),
                Self.sampleNote(id: secondID, title: "Second")
            ]
        )
        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {}, now: { archiveDate })

        sut.archiveSelectedNote()

        let archivedNote = try #require(sut.notes.first { $0.id == firstID })
        #expect(archivedNote.archivedAt == archiveDate)
        #expect(archivedNote.isPinned == false)
        #expect(sut.activeNotes.map(\.id) == [secondID])
        #expect(sut.archivedNotes.map(\.id) == [firstID])
        #expect(sut.selectedNoteID == secondID)
    }

    @Test func archiveAllowsAllActiveNotesToMoveToTrash() {
        let first = Self.sampleNote(title: "First")
        let repository = SpyNoteRepository(loadedNotes: [first])
        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {})

        sut.archiveSelectedNote()

        #expect(sut.activeNotes.isEmpty)
        #expect(sut.archivedNotes.count == 1)
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

        #expect(sut.activeNotes.map(\.id) == [firstID, secondID])
        #expect(sut.notes.first { $0.id == secondID }?.body == "- edited second")
    }

    @Test func restoreArchivedNoteReturnsItToActiveNotes() throws {
        let noteID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000701"))
        let restoreDate = Date(timeIntervalSince1970: 200)
        let repository = SpyNoteRepository(
            loadedNotes: [
                Self.sampleNote(id: noteID, title: "Archived", archivedAt: Date(timeIntervalSince1970: 100))
            ]
        )
        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {}, now: { restoreDate })

        sut.restoreArchivedNote(noteID)

        #expect(sut.notes.first { $0.id == noteID }?.archivedAt == nil)
        #expect(sut.notes.first { $0.id == noteID }?.updatedAt == restoreDate)
        #expect(sut.activeNotes.map(\.id) == [noteID])
        #expect(sut.selectedNoteID == noteID)
    }

    @Test func bindingIsUnavailableForArchivedNotes() throws {
        let noteID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000901"))
        let currentDate = Date(timeIntervalSince1970: 200)
        let repository = SpyNoteRepository(
            loadedNotes: [
                Self.sampleNote(id: noteID, title: "Archived", archivedAt: Date(timeIntervalSince1970: 100))
            ]
        )
        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {}, now: { currentDate })

        #expect(sut.binding(for: noteID) == nil)
    }

    @Test func initialSelectionFallsBackToArchivedNoteWhenNoActiveNotesRemain() throws {
        let noteID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000902"))
        let currentDate = Date(timeIntervalSince1970: 200)
        let repository = SpyNoteRepository(
            loadedNotes: [
                Self.sampleNote(id: noteID, title: "Archived", archivedAt: Date(timeIntervalSince1970: 100))
            ]
        )
        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {}, now: { currentDate })

        #expect(sut.selectedNoteID == noteID)
    }

    @Test func leaveTrashSelectsFirstActiveNote() throws {
        let activeID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000903"))
        let archivedID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000904"))
        let repository = SpyNoteRepository(
            loadedNotes: [
                Self.sampleNote(id: activeID, title: "Active"),
                Self.sampleNote(id: archivedID, title: "Archived", archivedAt: Date(timeIntervalSince1970: 100))
            ]
        )
        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {})
        sut.selectedNoteID = archivedID

        sut.leaveTrash()

        #expect(sut.selectedNoteID == activeID)
    }

    @Test func enterTrashSelectsMostRecentlyArchivedNote() throws {
        let activeID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000905"))
        let olderArchivedID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000906"))
        let recentArchivedID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000907"))
        let currentDate = Date(timeIntervalSince1970: 250)
        let repository = SpyNoteRepository(
            loadedNotes: [
                Self.sampleNote(id: activeID, title: "Active"),
                Self.sampleNote(id: olderArchivedID, title: "Older", archivedAt: Date(timeIntervalSince1970: 100)),
                Self.sampleNote(id: recentArchivedID, title: "Recent", archivedAt: Date(timeIntervalSince1970: 200))
            ]
        )
        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {}, now: { currentDate })
        sut.selectedNoteID = activeID

        sut.enterTrash()

        #expect(sut.selectedNoteID == recentArchivedID)
    }

    @Test func leaveTrashCreatesNoteWhenNoActiveNotesExist() {
        let repository = SpyNoteRepository(
            loadedNotes: [
                Self.sampleNote(title: "Archived", archivedAt: Date(timeIntervalSince1970: 100))
            ]
        )
        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {})

        sut.leaveTrash()

        #expect(sut.activeNotes.count == 1)
        #expect(sut.selectedNoteID == sut.activeNotes.first?.id)
        #expect(sut.selectedNote?.title == "New Cheat Sheet")
    }

    @Test func leaveTrashCanSkipCreatingNoteWhenCallerWillCreateOne() {
        let currentDate = Date(timeIntervalSince1970: 200)
        let repository = SpyNoteRepository(
            loadedNotes: [
                Self.sampleNote(title: "Archived", archivedAt: Date(timeIntervalSince1970: 100))
            ]
        )
        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {}, now: { currentDate })

        sut.leaveTrash(createNoteIfNeeded: false)

        #expect(sut.activeNotes.isEmpty)
        #expect(sut.archivedNotes.count == 1)
    }

    @Test func expiredArchivedNotesAreRemovedOnStartup() throws {
        let activeID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000801"))
        let expiredID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000802"))
        let freshID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000803"))
        let currentDate = Date(timeIntervalSince1970: 60 * 24 * 60 * 60)
        let repository = SpyNoteRepository(
            loadedNotes: [
                Self.sampleNote(id: activeID, title: "Active"),
                Self.sampleNote(id: expiredID, title: "Expired", archivedAt: currentDate.addingTimeInterval(-31 * 24 * 60 * 60)),
                Self.sampleNote(id: freshID, title: "Fresh", archivedAt: currentDate.addingTimeInterval(-2 * 24 * 60 * 60))
            ]
        )

        let sut = NoteStore(repository: repository, reloadWidgetTimelines: {}, now: { currentDate })

        #expect(sut.notes.map(\.id) == [activeID, freshID])
        #expect(repository.savedNotes.last?.map(\.id) == [activeID, freshID])
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
        isPinned: Bool = false,
        archivedAt: Date? = nil
    ) -> CheatSheetNote {
        CheatSheetNote(
            id: id,
            title: title,
            body: "- \(title)",
            isPinned: isPinned,
            updatedAt: Date(timeIntervalSince1970: 1),
            archivedAt: archivedAt
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

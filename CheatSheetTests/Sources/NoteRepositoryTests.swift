import Foundation
import SwiftData
import Testing

struct NoteRepositoryTests {
    @Test func loadsStarterNotesWhenNoDataExists() throws {
        let suite = "CheatSheetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let sut = UserDefaultsCheatSheetNoteRepository(defaults: defaults)

        #expect(sut.loadNotes() == CheatSheetNote.starterNotes)
    }

    @Test func savesAndLoadsNotesFromInjectedDefaults() throws {
        let suite = "CheatSheetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let sut = UserDefaultsCheatSheetNoteRepository(defaults: defaults)
        let notes = [
            CheatSheetNote(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
                title: "Build",
                body: "- xcodebuild",
                tintHex: CheatSheetPalette.mint.rawValue,
                isPinned: true,
                updatedAt: Date(timeIntervalSince1970: 10)
            )
        ]

        sut.saveNotes(notes)

        #expect(sut.loadNotes() == notes)
    }

    @Test func invalidStoredDataFallsBackToStarterNotes() throws {
        let suite = "CheatSheetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let sut = UserDefaultsCheatSheetNoteRepository(defaults: defaults)
        defaults.set(Data("not-json".utf8), forKey: "cheatSheet.notes")

        #expect(sut.loadNotes() == CheatSheetNote.starterNotes)
    }

    @Test func swiftDataRepositorySavesAndLoadsNotesInOrder() throws {
        let container = try SwiftDataCheatSheetNoteRepository.makeInMemoryContainer()
        let sut = SwiftDataCheatSheetNoteRepository(container: container)
        let notes = [
            CheatSheetNote(
                id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000101")),
                title: "First",
                body: "- first",
                tintHex: CheatSheetPalette.blue.rawValue,
                updatedAt: Date(timeIntervalSince1970: 1)
            ),
            CheatSheetNote(
                id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000102")),
                title: "Second",
                body: "- second",
                tintHex: CheatSheetPalette.mint.rawValue,
                isPinned: true,
                updatedAt: Date(timeIntervalSince1970: 2)
            )
        ]

        sut.saveNotes(notes)

        #expect(sut.loadNotes() == notes)
    }

    @Test func swiftDataRepositoryMigratesLegacyNotesWhenStoreIsEmpty() throws {
        let container = try SwiftDataCheatSheetNoteRepository.makeInMemoryContainer()
        let legacy = SpyLegacyRepository(
            notes: [
                CheatSheetNote(
                    id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000201")),
                    title: "Legacy",
                    body: "- migrate",
                    isPinned: true,
                    updatedAt: Date(timeIntervalSince1970: 3)
                )
            ]
        )
        let sut = SwiftDataCheatSheetNoteRepository(container: container, legacyRepository: legacy)

        let migratedNotes = sut.loadNotes()

        #expect(migratedNotes == legacy.notes)
        #expect(sut.loadNotes() == legacy.notes)
    }

    @Test func swiftDataRepositoryMirrorsSuccessfulSavesToLegacyRepository() throws {
        let container = try SwiftDataCheatSheetNoteRepository.makeInMemoryContainer()
        let legacy = SpyLegacyRepository(notes: [])
        let sut = SwiftDataCheatSheetNoteRepository(container: container, legacyRepository: legacy)
        let notes = [
            CheatSheetNote(
                id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000301")),
                title: "Mirror",
                body: "- mirror",
                updatedAt: Date(timeIntervalSince1970: 4)
            )
        ]

        sut.saveNotes(notes)

        #expect(legacy.savedNotes.last == notes)
    }

    @Test func swiftDataRepositoryUpdatesReordersAndDeletesNotesByID() throws {
        let container = try SwiftDataCheatSheetNoteRepository.makeInMemoryContainer()
        let sut = SwiftDataCheatSheetNoteRepository(container: container)
        let firstID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000401"))
        let secondID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000402"))
        let originalNotes = [
            CheatSheetNote(
                id: firstID,
                title: "First",
                body: "- first",
                updatedAt: Date(timeIntervalSince1970: 1)
            ),
            CheatSheetNote(
                id: secondID,
                title: "Second",
                body: "- second",
                updatedAt: Date(timeIntervalSince1970: 2)
            )
        ]
        let updatedNotes = [
            CheatSheetNote(
                id: secondID,
                title: "Updated Second",
                body: "- updated",
                tintHex: CheatSheetPalette.mint.rawValue,
                isPinned: true,
                updatedAt: Date(timeIntervalSince1970: 3)
            )
        ]

        sut.saveNotes(originalNotes)
        sut.saveNotes(updatedNotes)

        #expect(sut.loadNotes() == updatedNotes)
    }
}

private final class SpyLegacyRepository: CheatSheetNoteRepository {
    let notes: [CheatSheetNote]
    private(set) var savedNotes: [[CheatSheetNote]] = []

    init(notes: [CheatSheetNote]) {
        self.notes = notes
    }

    func loadNotes() -> [CheatSheetNote] {
        notes
    }

    func saveNotes(_ notes: [CheatSheetNote]) {
        savedNotes.append(notes)
    }
}

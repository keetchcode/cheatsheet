import Foundation
import SwiftData
import Testing

struct NoteRepositoryTests {
    @Test func appGroupIdentifierMatchesCurrentPlatform() {
        #if os(iOS)
        #expect(cheatSheetAppGroupID == "group.com.wesleykeetch.wesleycheatsheet")
        #else
        #expect(cheatSheetAppGroupID == "HD39MR492X.com.wesleykeetch.wesleycheatsheet")
        #endif
    }

    @Test func loadsStarterNotesWhenNoDataExists() throws {
        let suite = "CheatSheetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let sut = UserDefaultsCheatSheetNoteRepository(defaults: defaults)

        #expect(try sut.loadNotes() == CheatSheetNote.starterNotes)
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
                updatedAt: Date(timeIntervalSince1970: 10),
                archivedAt: Date(timeIntervalSince1970: 20)
            )
        ]

        try sut.saveNotes(notes)

        #expect(try sut.loadNotes() == notes)
    }

    @Test func savedEmptyNotesLoadsAsEmptyCollection() throws {
        let suite = "CheatSheetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let sut = UserDefaultsCheatSheetNoteRepository(defaults: defaults)

        try sut.saveNotes([])

        #expect(try sut.loadNotes().isEmpty)
    }

    @Test func invalidStoredDataThrowsInsteadOfMaskingCorruption() throws {
        let suite = "CheatSheetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let sut = UserDefaultsCheatSheetNoteRepository(defaults: defaults)
        defaults.set(Data("not-json".utf8), forKey: "cheatSheet.notes")

        // Returning starter notes here would look like a successful load, and the
        // next save would overwrite the still-recoverable stored payload.
        #expect(throws: CheatSheetStorageError.noteDecodingFailed) {
            try sut.loadNotes()
        }
    }

    @Test func missingStoredDataStillSeedsStarterNotes() throws {
        let suite = "CheatSheetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let sut = UserDefaultsCheatSheetNoteRepository(defaults: defaults)

        #expect(try sut.loadNotes() == CheatSheetNote.starterNotes)
    }

    @Test func malformedTintHexNormalizesToDefaultBlue() throws {
        let note = CheatSheetNote(title: "Invalid Tint", body: "- test", tintHex: "not-a-color")
        let encoded = try JSONEncoder().encode(note)
        let decoded = try JSONDecoder().decode(CheatSheetNote.self, from: encoded)

        #expect(note.tintHex == CheatSheetPalette.blue.rawValue)
        #expect(decoded.tintHex == CheatSheetPalette.blue.rawValue)
        #expect(CheatSheetPalette.normalizedHex(" #45c7c4 ") == CheatSheetPalette.cyan.rawValue)
    }

    @Test func widgetSnapshotCanRepresentNoActiveNote() throws {
        let suite = "CheatSheetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let sut = WidgetNoteSnapshotRepository(defaults: defaults)
        let note = CheatSheetNote(title: "Pinned", body: "- show in widget", isPinned: true)

        try sut.saveNote(note)
        #expect(sut.loadNote()?.title == "Pinned")

        try sut.saveNote(nil)
        #expect(sut.loadNote() == nil)
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
                updatedAt: Date(timeIntervalSince1970: 2),
                archivedAt: Date(timeIntervalSince1970: 3)
            )
        ]

        try sut.saveNotes(notes)

        #expect(try sut.loadNotes() == notes)
    }

    @Test func swiftDataRepositoryMigratesLegacyNotesWhenStoreIsEmpty() throws {
        let container = try SwiftDataCheatSheetNoteRepository.makeInMemoryContainer()
        let suite = "CheatSheetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
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
        let metadataRepository = CheatSheetStoreMetadataRepository(defaults: defaults)
        let sut = SwiftDataCheatSheetNoteRepository(
            container: container,
            legacyRepository: legacy,
            metadataRepository: metadataRepository
        )

        let migratedNotes = try sut.loadNotes()

        #expect(migratedNotes == legacy.notes)
        #expect(try sut.loadNotes() == legacy.notes)
        #expect(metadataRepository.hasInitializedSwiftDataStore)
    }

    @Test func swiftDataRepositoryKeepsEmptyStoreEmptyAfterInitialization() throws {
        let container = try SwiftDataCheatSheetNoteRepository.makeInMemoryContainer()
        let suite = "CheatSheetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let metadataRepository = CheatSheetStoreMetadataRepository(defaults: defaults)
        let sut = SwiftDataCheatSheetNoteRepository(
            container: container,
            legacyRepository: EmptyLegacyRepository(),
            metadataRepository: metadataRepository
        )

        try sut.saveNotes([])

        #expect(metadataRepository.hasInitializedSwiftDataStore)
        #expect(try sut.loadNotes().isEmpty)
    }

    @Test func swiftDataRepositoryDoesNotRestoreStaleLegacyNotesAfterDeletingEverything() throws {
        let container = try SwiftDataCheatSheetNoteRepository.makeInMemoryContainer()
        let suite = "CheatSheetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacyNotes = [CheatSheetNote(title: "Legacy", body: "- retained copy")]
        let metadataRepository = CheatSheetStoreMetadataRepository(defaults: defaults)
        let sut = SwiftDataCheatSheetNoteRepository(
            container: container,
            legacyRepository: SpyLegacyRepository(notes: legacyNotes),
            metadataRepository: metadataRepository
        )

        #expect(try sut.loadNotes() == legacyNotes)
        try sut.saveNotes([])

        #expect(metadataRepository.hasInitializedSwiftDataStore)
        #expect(try sut.loadNotes().isEmpty)
    }

    @Test func initializedEmptySwiftDataStoreIgnoresLegacyFirstRunStarterNotes() throws {
        let container = try SwiftDataCheatSheetNoteRepository.makeInMemoryContainer()
        let suite = "CheatSheetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacyRepository = UserDefaultsCheatSheetNoteRepository(defaults: defaults)
        let metadataRepository = CheatSheetStoreMetadataRepository(defaults: defaults)
        let sut = SwiftDataCheatSheetNoteRepository(
            container: container,
            legacyRepository: legacyRepository,
            metadataRepository: metadataRepository
        )

        try sut.saveNotes([])

        #expect(try legacyRepository.loadNotes() == CheatSheetNote.starterNotes)
        #expect(try sut.loadNotes().isEmpty)
    }

    @Test func factoryRefusesStaleLegacyFallbackAfterSwiftDataInitialization() throws {
        let suite = "CheatSheetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let metadataRepository = CheatSheetStoreMetadataRepository(defaults: defaults)
        metadataRepository.markSwiftDataStoreInitialized()
        let legacy = SpyLegacyRepository(notes: [
            CheatSheetNote(title: "Stale Legacy Note", body: "- old")
        ])

        let repository = CheatSheetNoteRepositoryFactory.fallbackRepository(
            metadataRepository: metadataRepository,
            legacyRepository: legacy
        )

        #expect(repository is UnavailableCheatSheetNoteRepository)
        #expect(throws: CheatSheetStorageError.repositoryUnavailable) {
            try repository.loadNotes()
        }
    }

    @Test func factoryAllowsLegacyFallbackBeforeSwiftDataInitialization() throws {
        let suite = "CheatSheetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let metadataRepository = CheatSheetStoreMetadataRepository(defaults: defaults)
        let legacyNotes = [CheatSheetNote(title: "Legacy Note", body: "- migrate")]
        let legacy = SpyLegacyRepository(notes: legacyNotes)

        let repository = CheatSheetNoteRepositoryFactory.fallbackRepository(
            metadataRepository: metadataRepository,
            legacyRepository: legacy
        )

        #expect(try repository.loadNotes() == legacyNotes)
    }

    @Test func swiftDataRepositorySavesWidgetSnapshotWithoutMirroringFullLegacyNotes() throws {
        let container = try SwiftDataCheatSheetNoteRepository.makeInMemoryContainer()
        let legacy = SpyLegacyRepository(notes: [])
        let suite = "CheatSheetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let widgetSnapshotRepository = WidgetNoteSnapshotRepository(defaults: defaults)
        let sut = SwiftDataCheatSheetNoteRepository(
            container: container,
            legacyRepository: legacy,
            widgetSnapshotRepository: widgetSnapshotRepository
        )
        let notes = [
            CheatSheetNote(
                id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000301")),
                title: "Mirror",
                body: "- mirror",
                updatedAt: Date(timeIntervalSince1970: 4)
            )
        ]

        try sut.saveNotes(notes)

        #expect(widgetSnapshotRepository.loadNote() == notes[0])
        #expect(legacy.savedNotes.isEmpty)
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

        try sut.saveNotes(originalNotes)
        try sut.saveNotes(updatedNotes)

        #expect(try sut.loadNotes() == updatedNotes)
    }

    @Test func swiftDataRepositoryDeduplicatesSavedNotesByID() throws {
        let container = try SwiftDataCheatSheetNoteRepository.makeInMemoryContainer()
        let legacy = SpyLegacyRepository(notes: [])
        let suite = "CheatSheetTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let widgetSnapshotRepository = WidgetNoteSnapshotRepository(defaults: defaults)
        let sut = SwiftDataCheatSheetNoteRepository(
            container: container,
            legacyRepository: legacy,
            widgetSnapshotRepository: widgetSnapshotRepository
        )
        let id = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000501"))
        let duplicateNotes = [
            CheatSheetNote(
                id: id,
                title: "Original",
                body: "- original",
                updatedAt: Date(timeIntervalSince1970: 1)
            ),
            CheatSheetNote(
                id: id,
                title: "Updated",
                body: "- updated",
                tintHex: CheatSheetPalette.mint.rawValue,
                isPinned: true,
                updatedAt: Date(timeIntervalSince1970: 2)
            )
        ]
        let expectedNotes = [duplicateNotes[1]]

        try sut.saveNotes(duplicateNotes)

        #expect(try sut.loadNotes() == expectedNotes)
        #expect(widgetSnapshotRepository.loadNote() == expectedNotes[0])
        #expect(legacy.savedNotes.isEmpty)
    }

}

private struct EmptyLegacyRepository: CheatSheetNoteRepository {
    func loadNotes() throws -> [CheatSheetNote] {
        []
    }

    func saveNotes(_ notes: [CheatSheetNote]) throws {}
}

private final class SpyLegacyRepository: CheatSheetNoteRepository, @unchecked Sendable {
    let notes: [CheatSheetNote]
    private(set) var savedNotes: [[CheatSheetNote]] = []

    init(notes: [CheatSheetNote]) {
        self.notes = notes
    }

    func loadNotes() throws -> [CheatSheetNote] {
        notes
    }

    func saveNotes(_ notes: [CheatSheetNote]) throws {
        savedNotes.append(notes)
    }
}

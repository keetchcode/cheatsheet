import Foundation
import SwiftData

public enum CheatSheetNoteRepositoryFactory {
    public static func live() -> any CheatSheetNoteRepository {
        do {
            return SwiftDataCheatSheetNoteRepository(
                container: try SwiftDataCheatSheetNoteRepository.makeDefaultContainer(),
                legacyRepository: try? UserDefaultsCheatSheetNoteRepository.appGroup(),
                widgetSnapshotRepository: try? WidgetNoteSnapshotRepository.appGroup(),
                metadataRepository: try? CheatSheetStoreMetadataRepository.appGroup()
            )
        } catch {
            do {
                return try UserDefaultsCheatSheetNoteRepository.appGroup()
            } catch {
                return UnavailableCheatSheetNoteRepository()
            }
        }
    }
}

public final class SwiftDataCheatSheetNoteRepository: CheatSheetNoteRepository, @unchecked Sendable {
    private let container: ModelContainer
    private let legacyRepository: (any CheatSheetNoteRepository)?
    private let widgetSnapshotRepository: WidgetNoteSnapshotRepository?
    private let metadataRepository: CheatSheetStoreMetadataRepository?

    init(
        container: ModelContainer,
        legacyRepository: (any CheatSheetNoteRepository)? = nil,
        widgetSnapshotRepository: WidgetNoteSnapshotRepository? = nil,
        metadataRepository: CheatSheetStoreMetadataRepository? = nil
    ) {
        self.container = container
        self.legacyRepository = legacyRepository
        self.widgetSnapshotRepository = widgetSnapshotRepository
        self.metadataRepository = metadataRepository
    }

    public func loadNotes() throws -> [CheatSheetNote] {
        let context = ModelContext(container)

        let persistedNotes = try context.fetch(Self.notesDescriptor)
        let notes = persistedNotes.map(\.note)

        guard notes.isEmpty else {
            metadataRepository?.markSwiftDataStoreInitialized()
            return notes
        }

        if let legacyNotes = try legacyRepository?.loadNotes(), legacyNotes.isEmpty == false {
            try saveNotes(legacyNotes)
            return legacyNotes
        }

        if metadataRepository?.hasInitializedSwiftDataStore == true {
            return []
        }

        let starterNotes = CheatSheetNote.starterNotes
        try saveNotes(starterNotes)
        return starterNotes
    }

    public func saveNotes(_ notes: [CheatSheetNote]) throws {
        let context = ModelContext(container)
        let notes = Self.uniqueNotesPreservingLastOccurrence(notes)

        let existingNotes = try context.fetch(Self.notesDescriptor)
        var existingNotesByID: [UUID: PersistedCheatSheetNote] = [:]
        var duplicateExistingNotes: [PersistedCheatSheetNote] = []

        for persistedNote in existingNotes {
            if existingNotesByID[persistedNote.id] == nil {
                existingNotesByID[persistedNote.id] = persistedNote
            } else {
                duplicateExistingNotes.append(persistedNote)
            }
        }

        for (index, note) in notes.enumerated() {
            if let persistedNote = existingNotesByID.removeValue(forKey: note.id) {
                persistedNote.update(with: note, sortIndex: index)
            } else {
                context.insert(PersistedCheatSheetNote(note: note, sortIndex: index))
            }
        }

        existingNotesByID.values.forEach(context.delete)
        duplicateExistingNotes.forEach(context.delete)

        try context.save()
        try widgetSnapshotRepository?.saveNote(notes.widgetDisplayNote)
        metadataRepository?.markSwiftDataStoreInitialized()
    }

    private static func uniqueNotesPreservingLastOccurrence(_ notes: [CheatSheetNote]) -> [CheatSheetNote] {
        var seenIDs: Set<CheatSheetNote.ID> = []
        var uniqueNotes: [CheatSheetNote] = []

        for note in notes.reversed() where seenIDs.insert(note.id).inserted {
            uniqueNotes.append(note)
        }

        return uniqueNotes.reversed()
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([PersistedCheatSheetNote.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static var notesDescriptor: FetchDescriptor<PersistedCheatSheetNote> {
        FetchDescriptor(sortBy: [SortDescriptor(\.sortIndex)])
    }

    static func makeDefaultContainer() throws -> ModelContainer {
        let schema = Schema([PersistedCheatSheetNote.self])
        let configuration = ModelConfiguration(schema: schema, url: try defaultStoreURL())
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func defaultStoreURL() throws -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: cheatSheetAppGroupID) else {
            throw CheatSheetStorageError.appGroupUnavailable(cheatSheetAppGroupID)
        }

        return containerURL.appending(path: "wesleycheatsheet.store")
    }
}

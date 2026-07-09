import Foundation

public protocol CheatSheetNoteRepository: Sendable {
    func loadNotes() throws -> [CheatSheetNote]
    func saveNotes(_ notes: [CheatSheetNote]) throws
}

public enum CheatSheetStorageError: Error, LocalizedError {
    case appGroupUnavailable(String)
    case repositoryUnavailable
    case noteEncodingFailed
    case widgetSnapshotEncodingFailed

    public var errorDescription: String? {
        switch self {
        case let .appGroupUnavailable(identifier):
            "App Group is unavailable: \(identifier)"
        case .repositoryUnavailable:
            "Note storage is unavailable."
        case .noteEncodingFailed:
            "Could not encode notes for storage."
        case .widgetSnapshotEncodingFailed:
            "Could not encode the widget note snapshot."
        }
    }
}

public enum CheatSheetAppGroup {
    public static func defaults() throws -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: cheatSheetAppGroupID) else {
            throw CheatSheetStorageError.appGroupUnavailable(cheatSheetAppGroupID)
        }

        return defaults
    }
}

public struct UserDefaultsCheatSheetNoteRepository: CheatSheetNoteRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let notesKey: String

    public init(
        defaults: UserDefaults,
        notesKey: String = "cheatSheet.notes"
    ) {
        self.defaults = defaults
        self.notesKey = notesKey
    }

    public static func appGroup(notesKey: String = "cheatSheet.notes") throws -> UserDefaultsCheatSheetNoteRepository {
        try UserDefaultsCheatSheetNoteRepository(defaults: CheatSheetAppGroup.defaults(), notesKey: notesKey)
    }

    public func loadNotes() throws -> [CheatSheetNote] {
        guard let data = defaults.data(forKey: notesKey) else {
            return CheatSheetNote.starterNotes
        }

        do {
            let notes = try JSONDecoder().decode([CheatSheetNote].self, from: data)
            return notes
        } catch {
            return CheatSheetNote.starterNotes
        }
    }

    public func saveNotes(_ notes: [CheatSheetNote]) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(notes)
        } catch {
            throw CheatSheetStorageError.noteEncodingFailed
        }

        defaults.set(data, forKey: notesKey)
    }
}

public struct UnavailableCheatSheetNoteRepository: CheatSheetNoteRepository {
    public init() {}

    public func loadNotes() throws -> [CheatSheetNote] {
        throw CheatSheetStorageError.repositoryUnavailable
    }

    public func saveNotes(_ notes: [CheatSheetNote]) throws {
        throw CheatSheetStorageError.repositoryUnavailable
    }
}

public struct WidgetNoteSnapshotRepository: @unchecked Sendable {
    private let defaults: UserDefaults
    private let noteKey: String

    public init(
        defaults: UserDefaults,
        noteKey: String = "cheatSheet.widgetNote"
    ) {
        self.defaults = defaults
        self.noteKey = noteKey
    }

    public static func appGroup(noteKey: String = "cheatSheet.widgetNote") throws -> WidgetNoteSnapshotRepository {
        try WidgetNoteSnapshotRepository(defaults: CheatSheetAppGroup.defaults(), noteKey: noteKey)
    }

    public func loadNote() -> CheatSheetNote? {
        guard let data = defaults.data(forKey: noteKey) else { return nil }
        return try? JSONDecoder().decode(CheatSheetNote.self, from: data)
    }

    public func saveNote(_ note: CheatSheetNote?) throws {
        guard let note else {
            defaults.removeObject(forKey: noteKey)
            return
        }

        let data: Data
        do {
            data = try JSONEncoder().encode(note)
        } catch {
            throw CheatSheetStorageError.widgetSnapshotEncodingFailed
        }

        defaults.set(data, forKey: noteKey)
    }
}

public struct CheatSheetStoreMetadataRepository: @unchecked Sendable {
    private let defaults: UserDefaults
    private let initializedKey: String

    public init(
        defaults: UserDefaults,
        initializedKey: String = "cheatSheet.hasInitializedSwiftDataStore"
    ) {
        self.defaults = defaults
        self.initializedKey = initializedKey
    }

    public static func appGroup(
        initializedKey: String = "cheatSheet.hasInitializedSwiftDataStore"
    ) throws -> CheatSheetStoreMetadataRepository {
        try CheatSheetStoreMetadataRepository(
            defaults: CheatSheetAppGroup.defaults(),
            initializedKey: initializedKey
        )
    }

    public var hasInitializedSwiftDataStore: Bool {
        defaults.bool(forKey: initializedKey)
    }

    public func markSwiftDataStoreInitialized() {
        defaults.set(true, forKey: initializedKey)
    }
}

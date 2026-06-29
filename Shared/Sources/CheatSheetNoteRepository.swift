import Foundation

public protocol CheatSheetNoteRepository {
    func loadNotes() -> [CheatSheetNote]
    func saveNotes(_ notes: [CheatSheetNote])
}

public enum CheatSheetStorageError: Error {
    case appGroupUnavailable(String)
}

public enum CheatSheetAppGroup {
    public static func defaults() throws -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: cheatSheetAppGroupID) else {
            throw CheatSheetStorageError.appGroupUnavailable(cheatSheetAppGroupID)
        }

        return defaults
    }
}

public struct UserDefaultsCheatSheetNoteRepository: CheatSheetNoteRepository {
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

    public func loadNotes() -> [CheatSheetNote] {
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

    public func saveNotes(_ notes: [CheatSheetNote]) {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        defaults.set(data, forKey: notesKey)
    }
}

public struct UnavailableCheatSheetNoteRepository: CheatSheetNoteRepository {
    public init() {}

    public func loadNotes() -> [CheatSheetNote] {
        CheatSheetNote.starterNotes
    }

    public func saveNotes(_ notes: [CheatSheetNote]) {}
}

public struct WidgetNoteSnapshotRepository {
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

    public func saveNote(_ note: CheatSheetNote?) {
        guard let note else {
            defaults.removeObject(forKey: noteKey)
            return
        }

        guard let data = try? JSONEncoder().encode(note) else { return }
        defaults.set(data, forKey: noteKey)
    }
}

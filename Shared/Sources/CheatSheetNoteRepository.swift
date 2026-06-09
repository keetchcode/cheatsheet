import Foundation

public protocol CheatSheetNoteRepository {
    func loadNotes() -> [CheatSheetNote]
    func saveNotes(_ notes: [CheatSheetNote])
}

public struct UserDefaultsCheatSheetNoteRepository: CheatSheetNoteRepository {
    private let defaults: UserDefaults
    private let notesKey: String

    public init(
        defaults: UserDefaults = UserDefaults(suiteName: cheatSheetAppGroupID) ?? .standard,
        notesKey: String = "cheatSheet.notes"
    ) {
        self.defaults = defaults
        self.notesKey = notesKey
    }

    public func loadNotes() -> [CheatSheetNote] {
        guard let data = defaults.data(forKey: notesKey) else {
            return CheatSheetNote.starterNotes
        }

        do {
            let notes = try JSONDecoder().decode([CheatSheetNote].self, from: data)
            return notes.isEmpty ? CheatSheetNote.starterNotes : notes
        } catch {
            return CheatSheetNote.starterNotes
        }
    }

    public func saveNotes(_ notes: [CheatSheetNote]) {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        defaults.set(data, forKey: notesKey)
    }
}

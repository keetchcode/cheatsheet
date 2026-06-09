import Foundation

public enum CheatSheetStorage {
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: cheatSheetAppGroupID) ?? .standard
    }

    public static func loadNotes() -> [CheatSheetNote] {
        CheatSheetNoteRepositoryFactory.live().loadNotes()
    }

    public static func saveNotes(_ notes: [CheatSheetNote]) {
        CheatSheetNoteRepositoryFactory.live().saveNotes(notes)
    }
}

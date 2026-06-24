import Foundation
import SwiftData

@Model
final class PersistedCheatSheetNote {
    @Attribute(.unique)
    var id: UUID
    var title: String
    var body: String
    var tintHex: String
    var fontStyleRawValue: String?
    var isPinned: Bool
    var updatedAt: Date
    var archivedAt: Date?
    var sortIndex: Int

    init(note: CheatSheetNote, sortIndex: Int) {
        id = note.id
        title = note.title
        body = note.body
        tintHex = note.tintHex
        fontStyleRawValue = note.fontStyleRawValue
        isPinned = note.isPinned
        updatedAt = note.updatedAt
        archivedAt = note.archivedAt
        self.sortIndex = sortIndex
    }

    func update(with note: CheatSheetNote, sortIndex: Int) {
        title = note.title
        body = note.body
        tintHex = note.tintHex
        fontStyleRawValue = note.fontStyleRawValue
        isPinned = note.isPinned
        updatedAt = note.updatedAt
        archivedAt = note.archivedAt
        self.sortIndex = sortIndex
    }

    var note: CheatSheetNote {
        CheatSheetNote(
            id: id,
            title: title,
            body: body,
            tintHex: tintHex,
            fontStyle: CheatSheetFontStyle(rawValue: fontStyleRawValue ?? "") ?? .monospaced,
            isPinned: isPinned,
            updatedAt: updatedAt,
            archivedAt: archivedAt
        )
    }
}

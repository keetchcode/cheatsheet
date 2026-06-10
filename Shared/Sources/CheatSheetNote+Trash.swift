import Foundation

public extension CheatSheetNote {
    var trashStatusText: String {
        trashStatusText(referenceDate: .now)
    }

    func trashStatusText(referenceDate: Date) -> String {
        guard let archivedAt else {
            return "This note is not in Trash."
        }

        let deletionDate = archivedAt.addingTimeInterval(NoteTrashPolicy.retentionInterval)
        let remainingSeconds = deletionDate.timeIntervalSince(referenceDate)

        if remainingSeconds <= 0 {
            return "This note is ready for permanent deletion."
        }

        let remainingDays = max(1, Int(ceil(remainingSeconds / NoteTrashPolicy.dayInterval)))
        if remainingDays == 1 {
            return "Deletes automatically in 1 day."
        }

        return "Deletes automatically in \(remainingDays) days."
    }
}

public enum NoteTrashPolicy {
    public static let dayInterval: TimeInterval = 24 * 60 * 60
    public static let retentionInterval: TimeInterval = 30 * dayInterval
}

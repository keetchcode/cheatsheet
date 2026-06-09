import OSLog
import WidgetKit

private let widgetLogger = Logger(subsystem: "com.wesleykeetch.CheatSheet.widgets", category: "Timeline")

struct CheatSheetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CheatSheetEntry {
        CheatSheetEntry(date: .now, note: CheatSheetNote.starterNotes[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (CheatSheetEntry) -> Void) {
        let note = pinnedNote(source: "snapshot")
        completion(CheatSheetEntry(date: .now, note: note))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CheatSheetEntry>) -> Void) {
        let entry = CheatSheetEntry(date: .now, note: pinnedNote(source: "timeline"))
        widgetLogger.info("Returning widget timeline for '\(entry.note.displayTitle, privacy: .public)'")
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 30))))
    }

    private func pinnedNote(source: StaticString) -> CheatSheetNote {
        let notes = UserDefaultsCheatSheetNoteRepository().loadNotes()
        let note = notes.first(where: \.isPinned) ?? notes.first ?? CheatSheetNote.starterNotes[0]
        widgetLogger.info("Loaded \(notes.count, privacy: .public) notes for \(source, privacy: .public); selected '\(note.displayTitle, privacy: .public)'")
        return note
    }
}

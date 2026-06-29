import OSLog
import WidgetKit

private let widgetLogger = Logger(subsystem: "com.wesleykeetch.wesleycheatsheet.widgets", category: "Timeline")

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
        widgetLogger.info("Returning widget timeline for '\(entry.note.displayTitle, privacy: .private)'")
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 30))))
    }

    private func pinnedNote(source: StaticString) -> CheatSheetNote {
        let note = (try? WidgetNoteSnapshotRepository.appGroup().loadNote()) ?? CheatSheetNote.starterNotes[0]
        widgetLogger.info("Loaded widget snapshot for \(source, privacy: .public); selected '\(note.displayTitle, privacy: .private)'")
        return note
    }
}

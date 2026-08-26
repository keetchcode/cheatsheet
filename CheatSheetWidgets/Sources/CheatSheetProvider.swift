import OSLog
import WidgetKit

private let widgetLogger = Logger(subsystem: "com.wesleykeetch.wesleycheatsheet.widgets", category: "Timeline")

struct CheatSheetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CheatSheetEntry {
        CheatSheetEntry(date: .now, note: CheatSheetNote.starterNotes[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (CheatSheetEntry) -> Void) {
        let note = widgetNote(source: "snapshot")
        completion(CheatSheetEntry(date: .now, note: note))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CheatSheetEntry>) -> Void) {
        let entry = CheatSheetEntry(date: .now, note: widgetNote(source: "timeline"))
        if let note = entry.note {
            widgetLogger.info("Returning widget timeline for '\(note.displayTitle, privacy: .private)'")
        } else {
            widgetLogger.info("Returning empty widget timeline")
        }
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 30))))
    }

    private func widgetNote(source: StaticString) -> CheatSheetNote? {
        do {
            let note = try WidgetNoteSnapshotRepository.appGroup().loadNote()
            if let note {
                widgetLogger.info("Loaded widget snapshot for \(source, privacy: .public); selected '\(note.displayTitle, privacy: .private)'")
            } else {
                widgetLogger.info("Loaded empty widget snapshot for \(source, privacy: .public)")
            }
            return note
        } catch {
            widgetLogger.error("Unable to load widget snapshot for \(source, privacy: .public): \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }
}

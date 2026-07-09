import Foundation
import Observation
import OSLog
import SwiftUI
import WidgetKit

private let noteStoreLogger = Logger(subsystem: "com.wesleykeetch.wesleycheatsheet", category: "Persistence")

enum PersistenceStatus: Equatable {
    case ready
    case saving
    case saved(Date)
    case loadFailed(String)
    case saveFailed(String)

    var isFailure: Bool {
        switch self {
        case .loadFailed, .saveFailed: true
        case .ready, .saving, .saved: false
        }
    }
}

@Observable
@MainActor
final class NoteStore {
    var notes: [CheatSheetNote] {
        didSet {
            rebuildNoteCaches()
        }
    }
    var searchText = ""
    private(set) var persistenceStatus: PersistenceStatus = .ready
    private(set) var activeNotes: [CheatSheetNote] = []
    private(set) var archivedNotes: [CheatSheetNote] = []

    var selectedNoteID: CheatSheetNote.ID? {
        didSet {
            guard selectedNoteID == nil else { return }
            guard let fallbackNoteID = activeNotes.first?.id ?? archivedNotes.first?.id else { return }
            selectedNoteID = fallbackNoteID
        }
    }

    @ObservationIgnored
    private let repository: any CheatSheetNoteRepository
    @ObservationIgnored
    private let reloadWidgetTimelines: () -> Void
    @ObservationIgnored
    private let now: () -> Date
    @ObservationIgnored
    private let persistenceWorker: NotePersistenceWorker
    @ObservationIgnored
    private var lastReloadedWidgetNote: CheatSheetNote?
    @ObservationIgnored
    private var saveTask: Task<Void, Never>?

    init(
        repository: any CheatSheetNoteRepository = CheatSheetNoteRepositoryFactory.live(),
        reloadWidgetTimelines: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() },
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.reloadWidgetTimelines = reloadWidgetTimelines
        self.now = now
        persistenceWorker = NotePersistenceWorker(repository: repository)

        let storedNotes: [CheatSheetNote]
        let loadError: (any Error)?
        do {
            storedNotes = try repository.loadNotes()
            loadError = nil
            persistenceStatus = .ready
        } catch {
            storedNotes = CheatSheetNote.starterNotes
            loadError = error
        }

        notes = Self.removingExpiredArchivedNotes(from: storedNotes, now: now())
        rebuildNoteCaches()
        selectedNoteID = activeNotes.first(where: \.isPinned)?.id ?? activeNotes.first?.id ?? archivedNotes.first?.id
        lastReloadedWidgetNote = Self.widgetNote(in: notes)
        if let loadError {
            handleLoadFailure(loadError)
        }
        reloadWidgetTimelines()

        if notes != storedNotes {
            persistImmediately()
        }
    }

    var filteredNotes: [CheatSheetNote] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return activeNotes }

        return activeNotes.filter { note in
            note.title.localizedCaseInsensitiveContains(query)
            || note.body.localizedCaseInsensitiveContains(query)
        }
    }

    var filteredArchivedNotes: [CheatSheetNote] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return archivedNotes }

        return archivedNotes.filter { note in
            note.title.localizedCaseInsensitiveContains(query)
            || note.body.localizedCaseInsensitiveContains(query)
        }
    }

    var selectedNote: CheatSheetNote? {
        guard let selectedNoteID else { return nil }
        return notes.first { $0.id == selectedNoteID }
    }

    func binding(for id: CheatSheetNote.ID) -> Binding<CheatSheetNote>? {
        guard let initialNote = notes.first(where: { $0.id == id && !$0.isArchived }) else { return nil }

        return Binding {
            self.notes.first { $0.id == id } ?? initialNote
        } set: { updatedNote in
            guard let index = self.notes.firstIndex(where: { $0.id == id }) else { return }
            var note = updatedNote
            note.updatedAt = self.now()
            self.notes[index] = note
            self.schedulePersist()
        }
    }

    @discardableResult
    func addNote(
        title: String = "New Cheat Sheet",
        body: String = "# New Cheat Sheet\n- ",
        tintHex: String = CheatSheetPalette.blue.rawValue
    ) -> CheatSheetNote.ID {
        let note = CheatSheetNote(
            title: title,
            body: body,
            tintHex: tintHex
        )
        notes.insert(note, at: 0)
        selectedNoteID = note.id
        persistImmediately()
        return note.id
    }

    func note(with id: CheatSheetNote.ID) -> CheatSheetNote? {
        notes.first { $0.id == id }
    }

    func archiveSelectedNote() {
        guard let selectedNoteID else { return }
        archiveNote(selectedNoteID)
    }

    func archiveNote(_ noteID: CheatSheetNote.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID && !$0.isArchived }) else { return }
        let archiveDate = now()
        notes[index].archivedAt = archiveDate
        notes[index].isPinned = false
        notes[index].updatedAt = archiveDate
        selectedNoteID = activeNotes.first?.id ?? noteID
        persistImmediately()
    }

    func restoreArchivedNote(_ noteID: CheatSheetNote.ID) {
        guard let index = notes.firstIndex(where: { $0.id == noteID && $0.isArchived }) else { return }
        notes[index].archivedAt = nil
        notes[index].updatedAt = now()
        selectedNoteID = noteID
        persistImmediately()
    }

    func permanentlyDeleteArchivedNote(_ noteID: CheatSheetNote.ID) {
        guard notes.contains(where: { $0.id == noteID && $0.isArchived }) else { return }
        notes.removeAll { $0.id == noteID && $0.isArchived }
        selectedNoteID = activeNotes.first?.id ?? archivedNotes.first?.id
        persistImmediately()
    }

    func enterTrash() {
        guard let archivedNoteID = archivedNotes.first?.id else { return }
        selectedNoteID = archivedNoteID
    }

    func leaveTrash(createNoteIfNeeded: Bool = true) {
        guard let activeNoteID = activeNotes.first?.id else {
            if createNoteIfNeeded {
                addNote()
            }
            return
        }

        selectedNoteID = activeNoteID
    }

    func setPinned(_ noteID: CheatSheetNote.ID) {
        notes = notes.map { note in
            var copy = note
            copy.isPinned = !note.isArchived && note.id == noteID
            copy.updatedAt = note.id == noteID ? now() : note.updatedAt
            return copy
        }
        selectedNoteID = noteID
        persistImmediately()
    }

    func flushPendingChanges() {
        let snapshot = snapshotForPersistence()
        saveTask?.cancel()
        startSaveTask(for: snapshot)
    }

    func flushPendingChanges() async {
        let snapshot = snapshotForPersistence()
        saveTask?.cancel()
        saveTask = nil
        await persist(snapshot)
    }

    private func schedulePersist() {
        let snapshot = snapshotForPersistence()
        saveTask?.cancel()
        startSaveTask(for: snapshot, delay: .milliseconds(400))
    }

    private func persistImmediately() {
        let snapshot = snapshotForPersistence()
        saveTask?.cancel()
        startSaveTask(for: snapshot)
    }

    private func startSaveTask(for snapshot: [CheatSheetNote], delay: Duration? = nil) {
        persistenceStatus = .saving
        saveTask = Task { [weak self, persistenceWorker] in
            do {
                if let delay {
                    try await Task.sleep(for: delay)
                }

                try await persistenceWorker.save(snapshot)
                self?.handleSaveSuccess(for: snapshot)
            } catch is CancellationError {
                return
            } catch {
                self?.handleSaveFailure(error)
                return
            }
        }
    }

    private func persist(_ snapshot: [CheatSheetNote]) async {
        persistenceStatus = .saving

        do {
            try await persistenceWorker.save(snapshot)
            handleSaveSuccess(for: snapshot)
        } catch {
            handleSaveFailure(error)
        }
    }

    private func snapshotForPersistence() -> [CheatSheetNote] {
        purgeExpiredArchivedNotes()
        ensureSelectionIsValid()
        return notes
    }

    private func handleLoadFailure(_ error: Error) {
        let message = Self.storageMessage(for: error)
        persistenceStatus = .loadFailed(message)
        noteStoreLogger.error("Failed to load notes: \(message, privacy: .public)")
    }

    private func handleSaveSuccess(for snapshot: [CheatSheetNote]) {
        persistenceStatus = .saved(now())
        reloadWidgetTimelinesIfNeeded(for: snapshot)
        saveTask = nil
    }

    private func handleSaveFailure(_ error: Error) {
        let message = Self.storageMessage(for: error)
        persistenceStatus = .saveFailed(message)
        noteStoreLogger.error("Failed to save notes: \(message, privacy: .public)")
        saveTask = nil
    }

    private static func storageMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        return error.localizedDescription
    }

    private func reloadWidgetTimelinesIfNeeded(for notes: [CheatSheetNote]) {
        let widgetNote = Self.widgetNote(in: notes)
        guard widgetNote != lastReloadedWidgetNote else { return }

        lastReloadedWidgetNote = widgetNote
        reloadWidgetTimelines()
    }

    private static func widgetNote(in notes: [CheatSheetNote]) -> CheatSheetNote? {
        notes.widgetDisplayNote
    }

    private static func sorted(_ notes: [CheatSheetNote]) -> [CheatSheetNote] {
        notes.enumerated().sorted { lhs, rhs in
            if lhs.element.isPinned != rhs.element.isPinned {
                return lhs.element.isPinned
            }

            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    private func rebuildNoteCaches() {
        activeNotes = Self.sorted(notes.filter { !$0.isArchived })
        archivedNotes = notes.filter(\.isArchived).sorted { lhs, rhs in
            (lhs.archivedAt ?? .distantPast) > (rhs.archivedAt ?? .distantPast)
        }
    }

    private func purgeExpiredArchivedNotes() {
        let cutoff = now().addingTimeInterval(-NoteTrashPolicy.retentionInterval)
        notes.removeAll { note in
            guard let archivedAt = note.archivedAt else { return false }
            return archivedAt <= cutoff
        }
    }

    private func ensureSelectionIsValid() {
        guard let selectedNoteID, notes.contains(where: { $0.id == selectedNoteID }) else {
            selectedNoteID = activeNotes.first?.id ?? archivedNotes.first?.id
            return
        }
    }

    private static func removingExpiredArchivedNotes(from notes: [CheatSheetNote], now: Date) -> [CheatSheetNote] {
        let cutoff = now.addingTimeInterval(-NoteTrashPolicy.retentionInterval)
        return notes.filter { note in
            guard let archivedAt = note.archivedAt else { return true }
            return archivedAt > cutoff
        }
    }
}

private actor NotePersistenceWorker {
    private let repository: any CheatSheetNoteRepository

    init(repository: any CheatSheetNoteRepository) {
        self.repository = repository
    }

    func save(_ notes: [CheatSheetNote]) throws {
        try repository.saveNotes(notes)
    }
}

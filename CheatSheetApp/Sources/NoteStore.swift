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
    /// Set when the initial load failed. Saving a snapshot the store never
    /// managed to read would overwrite the durable store with partial data, so
    /// persistence stays suspended until a reload succeeds.
    @ObservationIgnored
    private(set) var isPersistenceSuspended = false
    @ObservationIgnored
    private var saveGeneration = 0

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
            // Start empty rather than with starter notes: starter content is
            // indistinguishable from real data to the user, and persisting it
            // would destroy whatever the store still holds.
            storedNotes = []
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

    func flushPendingChanges() async {
        guard !isPersistenceSuspended else { return }
        let snapshot = snapshotForPersistence()
        saveTask?.cancel()
        saveTask = nil
        await persist(snapshot)
    }

    /// Re-reads the durable store after a failed load. On success the in-memory
    /// notes are replaced and persistence resumes.
    func retryLoad() {
        do {
            let storedNotes = try repository.loadNotes()
            notes = Self.removingExpiredArchivedNotes(from: storedNotes, now: now())
            selectedNoteID = activeNotes.first(where: \.isPinned)?.id
                ?? activeNotes.first?.id
                ?? archivedNotes.first?.id
            lastReloadedWidgetNote = Self.widgetNote(in: notes)
            isPersistenceSuspended = false
            persistenceStatus = .ready
        } catch {
            handleLoadFailure(error)
        }
    }

    private func schedulePersist() {
        guard !isPersistenceSuspended else { return }
        let snapshot = snapshotForPersistence()
        saveTask?.cancel()
        startSaveTask(for: snapshot, delay: .milliseconds(400))
    }

    private func persistImmediately() {
        guard !isPersistenceSuspended else { return }
        let snapshot = snapshotForPersistence()
        saveTask?.cancel()
        startSaveTask(for: snapshot)
    }

    private func startSaveTask(for snapshot: [CheatSheetNote], delay: Duration? = nil) {
        let generation = beginSave()
        saveTask = Task { [weak self, persistenceWorker] in
            do {
                if let delay {
                    try await Task.sleep(for: delay)
                }

                try await persistenceWorker.save(snapshot)
                self?.handleSaveSuccess(for: snapshot, generation: generation)
            } catch is CancellationError {
                return
            } catch {
                self?.handleSaveFailure(error, generation: generation)
                return
            }
        }
    }

    private func persist(_ snapshot: [CheatSheetNote]) async {
        let generation = beginSave()

        do {
            try await persistenceWorker.save(snapshot)
            handleSaveSuccess(for: snapshot, generation: generation)
        } catch {
            handleSaveFailure(error, generation: generation)
        }
    }

    /// Marks a new save as the current one. A cancelled task may still finish its
    /// in-flight repository work, so completions carry the generation they were
    /// started with and stale ones are ignored.
    private func beginSave() -> Int {
        saveGeneration += 1
        persistenceStatus = .saving
        return saveGeneration
    }

    private func snapshotForPersistence() -> [CheatSheetNote] {
        purgeExpiredArchivedNotes()
        ensureSelectionIsValid()
        return notes
    }

    private func handleLoadFailure(_ error: Error) {
        let message = Self.storageMessage(for: error)
        persistenceStatus = .loadFailed(message)
        isPersistenceSuspended = true
        noteStoreLogger.error("Failed to load notes: \(message, privacy: .public)")
    }

    private func handleSaveSuccess(for snapshot: [CheatSheetNote], generation: Int) {
        reloadWidgetTimelinesIfNeeded(for: snapshot)
        guard generation == saveGeneration else { return }
        persistenceStatus = .saved(now())
        saveTask = nil
    }

    private func handleSaveFailure(_ error: Error, generation: Int) {
        let message = Self.storageMessage(for: error)
        noteStoreLogger.error("Failed to save notes: \(message, privacy: .public)")
        guard generation == saveGeneration else { return }
        persistenceStatus = .saveFailed(message)
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
        try Task.checkCancellation()
        try repository.saveNotes(notes)
    }
}

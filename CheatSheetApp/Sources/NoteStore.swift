import Foundation
import Observation
import SwiftUI
import WidgetKit

@Observable
@MainActor
final class NoteStore {
    var notes: [CheatSheetNote]
    var searchText = ""

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

        let storedNotes = repository.loadNotes()
        notes = Self.removingExpiredArchivedNotes(from: storedNotes, now: now())
        selectedNoteID = activeNotes.first(where: \.isPinned)?.id ?? activeNotes.first?.id ?? archivedNotes.first?.id
        lastReloadedWidgetNote = Self.widgetNote(in: notes)
        reloadWidgetTimelines()

        if notes != storedNotes {
            persistImmediately()
        }
    }

    var activeNotes: [CheatSheetNote] {
        Self.sorted(notes.filter { !$0.isArchived })
    }

    var archivedNotes: [CheatSheetNote] {
        notes.filter(\.isArchived).sorted { lhs, rhs in
            (lhs.archivedAt ?? .distantPast) > (rhs.archivedAt ?? .distantPast)
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

    func addNote() {
        let note = CheatSheetNote(
            title: "New Cheat Sheet",
            body: "# New Cheat Sheet\n- ",
            tintHex: CheatSheetPalette.blue.rawValue
        )
        notes.insert(note, at: 0)
        selectedNoteID = note.id
        persistImmediately()
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
        persistImmediately()
    }

    private func schedulePersist() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(400))
            } catch {
                return
            }

            self?.persist()
            self?.saveTask = nil
        }
    }

    private func persistImmediately() {
        saveTask?.cancel()
        saveTask = nil
        persist()
    }

    private func persist() {
        purgeExpiredArchivedNotes()
        ensureSelectionIsValid()
        repository.saveNotes(notes)
        reloadWidgetTimelinesIfNeeded(for: notes)
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

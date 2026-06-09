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
            selectedNoteID = sortedNotes.first?.id
        }
    }

    @ObservationIgnored
    private let repository: any CheatSheetNoteRepository
    @ObservationIgnored
    private let reloadWidgetTimelines: () -> Void
    @ObservationIgnored
    private var lastReloadedWidgetNote: CheatSheetNote?
    @ObservationIgnored
    private var saveTask: Task<Void, Never>?

    init(
        repository: any CheatSheetNoteRepository = UserDefaultsCheatSheetNoteRepository(),
        reloadWidgetTimelines: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }
    ) {
        self.repository = repository
        self.reloadWidgetTimelines = reloadWidgetTimelines

        let storedNotes = repository.loadNotes()
        notes = storedNotes
        selectedNoteID = Self.sorted(storedNotes).first(where: \.isPinned)?.id ?? Self.sorted(storedNotes).first?.id
        lastReloadedWidgetNote = Self.widgetNote(in: storedNotes)
        reloadWidgetTimelines()
    }

    var sortedNotes: [CheatSheetNote] {
        Self.sorted(notes)
    }

    var filteredNotes: [CheatSheetNote] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sortedNotes }

        return sortedNotes.filter { note in
            note.title.localizedCaseInsensitiveContains(query)
            || note.body.localizedCaseInsensitiveContains(query)
        }
    }

    var selectedNote: CheatSheetNote? {
        guard let selectedNoteID else { return nil }
        return notes.first { $0.id == selectedNoteID }
    }

    func binding(for id: CheatSheetNote.ID) -> Binding<CheatSheetNote>? {
        guard let initialNote = notes.first(where: { $0.id == id }) else { return nil }

        return Binding {
            self.notes.first { $0.id == id } ?? initialNote
        } set: { updatedNote in
            guard let index = self.notes.firstIndex(where: { $0.id == id }) else { return }
            var note = updatedNote
            note.updatedAt = .now
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

    func deleteSelectedNote() {
        guard let selectedNoteID, notes.count > 1 else { return }
        notes.removeAll { $0.id == selectedNoteID }
        self.selectedNoteID = sortedNotes.first?.id
        persistImmediately()
    }

    func setPinned(_ noteID: CheatSheetNote.ID) {
        notes = notes.map { note in
            var copy = note
            copy.isPinned = note.id == noteID
            copy.updatedAt = note.id == noteID ? .now : note.updatedAt
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
        notes.first(where: \.isPinned) ?? notes.first
    }

    private static func sorted(_ notes: [CheatSheetNote]) -> [CheatSheetNote] {
        notes.enumerated().sorted { lhs, rhs in
            if lhs.element.isPinned != rhs.element.isPinned {
                return lhs.element.isPinned
            }

            return lhs.offset < rhs.offset
        }.map(\.element)
    }
}

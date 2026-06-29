import Observation
import SwiftUI

struct SidebarView: View {
    @Bindable var store: NoteStore
    let isShowingTrash: Bool

    var body: some View {
        let notes = isShowingTrash ? store.filteredArchivedNotes : store.filteredNotes

        List(selection: $store.selectedNoteID) {
            if isShowingTrash {
                Section("Trash") {
                    if notes.isEmpty {
                        Text("Trash is empty")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(notes) { note in
                            SidebarNoteRow(note: note)
                                .tag(note.id)
                        }
                    }
                }
            } else {
                Section("Notes") {
                    ForEach(notes) { note in
                        SidebarNoteRow(note: note)
                            .tag(note.id)
                    }
                }
            }
        }
        .navigationTitle(isShowingTrash ? "Trash" : "CheatSheet")
        .searchable(
            text: $store.searchText,
            placement: .sidebar,
            prompt: isShowingTrash ? "Search trash" : "Search notes"
        )
        .listStyle(.sidebar)
    }
}

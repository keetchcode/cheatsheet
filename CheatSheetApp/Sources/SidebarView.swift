import Observation
import SwiftUI

struct SidebarView: View {
    @Bindable var store: NoteStore
    let isShowingTrash: Bool

    var body: some View {
        List(selection: $store.selectedNoteID) {
            if isShowingTrash {
                Section("Trash") {
                    if store.filteredArchivedNotes.isEmpty {
                        Text("Trash is empty")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.filteredArchivedNotes) { note in
                            SidebarNoteRow(note: note)
                                .tag(note.id)
                        }
                    }
                }
            } else {
                Section("Notes") {
                    ForEach(store.filteredNotes) { note in
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

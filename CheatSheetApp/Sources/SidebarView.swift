import Observation
import SwiftUI

struct SidebarView: View {
    @Bindable var store: NoteStore

    var body: some View {
        List(selection: $store.selectedNoteID) {
            Section("Notes") {
                ForEach(store.filteredNotes) { note in
                    SidebarNoteRow(note: note)
                        .tag(note.id)
                }
            }
        }
        .navigationTitle("CheatSheet")
        .searchable(text: $store.searchText, placement: .sidebar, prompt: "Search notes")
        .listStyle(.sidebar)
    }
}

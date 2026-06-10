import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("showWidgetHints") private var showWidgetHints = true
    @State private var store = NoteStore()
    @State private var isShowingOnboarding = false
    @State private var isShowingTrash = false

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, isShowingTrash: isShowingTrash)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            if isShowingTrash {
                trashDetail
            } else if let selectedNoteID = store.selectedNoteID,
                      let note = store.binding(for: selectedNoteID) {
                editorDetail(note: note, selectedNoteID: selectedNoteID)
            } else {
                EmptyStateView {
                    showNotes(createNoteIfNeeded: false)
                    store.addNote()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.blue)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showNotes(createNoteIfNeeded: false)
                    store.addNote()
                } label: {
                    Label("New Note", systemImage: "plus")
                }
                .keyboardShortcut("n")

                Button(role: .destructive) {
                    store.archiveSelectedNote()
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
                .help("Move the selected note to Trash for 30 days")
                .disabled(store.selectedNote?.isArchived ?? true)

                Button {
                    isShowingTrash ? showNotes() : showTrash()
                } label: {
                    Label(isShowingTrash ? "Show Notes" : "Show Trash", systemImage: isShowingTrash ? "note.text" : "archivebox")
                }
                .help(isShowingTrash ? "Show Notes" : "Show Trash")
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active else { return }
            store.flushPendingChanges()
        }
        .task {
            isShowingOnboarding = !hasCompletedOnboarding
        }
        .sheet(isPresented: $isShowingOnboarding) {
            OnboardingView()
        }
    }

    @ViewBuilder
    private var trashDetail: some View {
        if let selectedNote = store.selectedNote, selectedNote.isArchived {
            TrashNoteView(note: selectedNote) {
                showNotes()
            } restoreAction: {
                store.restoreArchivedNote(selectedNote.id)
                showNotes()
            } deleteNowAction: {
                store.permanentlyDeleteArchivedNote(selectedNote.id)
            }
            .padding(AppDesign.windowPadding)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "archivebox")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Trash is empty")
                    .font(.title3.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func editorDetail(note: Binding<CheatSheetNote>, selectedNoteID: CheatSheetNote.ID) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.panelSpacing) {
            if showWidgetHints, !note.wrappedValue.isPinned {
                widgetSetupHint {
                    store.setPinned(selectedNoteID)
                }
            }

            EditorView(note: note) {
                store.setPinned(selectedNoteID)
            }
        }
        .padding(AppDesign.windowPadding)
    }

    private func showTrash() {
        store.searchText = ""
        store.enterTrash()
        isShowingTrash = true
    }

    private func showNotes(createNoteIfNeeded: Bool = true) {
        store.searchText = ""
        isShowingTrash = false
        store.leaveTrash(createNoteIfNeeded: createNoteIfNeeded)
    }

    private func widgetSetupHint(pinAction: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Label("Ready for the widget", systemImage: "pin")
                .font(.headline)

            Text("Pin this note to show it on your desktop widget.")
                .foregroundStyle(.secondary)

            Spacer()

            Button("Hide") {
                showWidgetHints = false
            }

            Button("Pin", systemImage: "pin", action: pinAction)
                .glassCompatibleButtonStyle(prominent: true)
        }
        .padding(AppDesign.panelPadding)
        .background(.regularMaterial, in: .rect(cornerRadius: AppDesign.controlCornerRadius))
    }
}

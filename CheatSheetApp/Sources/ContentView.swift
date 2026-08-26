import Observation
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("showWidgetHints") private var showWidgetHints = true
    let store: NoteStore
    @State private var isShowingOnboarding = false
    @State private var isShowingTrash = false
    @State private var compactPath: [CheatSheetNote.ID] = []

    var body: some View {
        adaptiveContent
            .disabled(store.isPersistenceSuspended)
            .safeAreaInset(edge: .top, spacing: 0) {
                PersistenceStatusBanner(
                    status: store.persistenceStatus,
                    canRetryLoad: store.isPersistenceSuspended,
                    retryAction: store.retryLoad
                )
            }
            .tint(.blue)
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase != .active else { return }
                Task {
                    await store.flushPendingChanges()
                }
            }
            .task {
                isShowingOnboarding = !hasCompletedOnboarding
            }
            .sheet(isPresented: $isShowingOnboarding) {
                OnboardingView()
            }
    }

    @ViewBuilder
    private var adaptiveContent: some View {
        #if os(iOS)
        rootContent
            .onChange(of: horizontalSizeClass) { _, newSizeClass in
                if newSizeClass == .compact, let selectedNoteID = store.selectedNoteID {
                    compactPath = [selectedNoteID]
                } else {
                    compactPath.removeAll()
                }
            }
        #else
        rootContent
        #endif
    }

    @ViewBuilder
    private var rootContent: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            compactRoot
        } else {
            splitRoot
        }
        #else
        splitRoot
        #endif
    }

    /// Attached inside each navigation container rather than to `rootContent`.
    /// A `.toolbar` applied to a `NavigationStack` itself never installs bar
    /// items, which left the compact iPhone layout with no visible actions.
    @ToolbarContentBuilder
    private var contentToolbar: some ToolbarContent {
        ContentToolbar(
            isShowingTrash: isShowingTrash,
            selectedNoteIsArchived: store.selectedNote?.isArchived ?? true,
            createAction: createNote,
            archiveAction: {
                store.archiveSelectedNote()
                compactPath.removeAll()
            },
            toggleTrashAction: {
                isShowingTrash ? showNotes() : showTrash()
            }
        )
    }

    private var splitRoot: some View {
        NavigationSplitView {
            SidebarView(store: store, isShowingTrash: isShowingTrash)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            // On iPad the detail column owns the navigation bar, so the toolbar
            // has to attach here or `.topBarTrailing` items never appear. macOS
            // keeps the toolbar on the split view, where it already renders into
            // the unified window toolbar.
            #if os(iOS)
            splitDetail.toolbar { contentToolbar }
            #else
            splitDetail
            #endif
        }
        .navigationSplitViewStyle(.balanced)
        #if os(macOS)
        .toolbar { contentToolbar }
        #endif
    }

    @ViewBuilder
    private var splitDetail: some View {
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

    #if os(iOS)
    private var compactRoot: some View {
        NavigationStack(path: $compactPath) {
            CompactNoteListView(
                store: store,
                isShowingTrash: isShowingTrash,
                addAction: createNote
            )
            .navigationDestination(for: CheatSheetNote.ID.self) { noteID in
                compactDestination(for: noteID)
            }
            .toolbar { contentToolbar }
        }
    }
    #endif

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
            TrashEmptyStateView()
        }
    }

    #if os(iOS)
    @ViewBuilder
    private func compactDestination(for noteID: CheatSheetNote.ID) -> some View {
        if isShowingTrash, let note = store.note(with: noteID), note.isArchived {
            TrashNoteView(note: note) {
                showNotes()
            } restoreAction: {
                store.restoreArchivedNote(noteID)
                showNotes()
            } deleteNowAction: {
                store.permanentlyDeleteArchivedNote(noteID)
                compactPath.removeAll()
            }
            .padding(AppDesign.compactContentPadding)
            .navigationTitle(note.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                store.selectedNoteID = noteID
            }
        } else if let note = store.binding(for: noteID) {
            editorDetail(note: note, selectedNoteID: noteID)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    store.selectedNoteID = noteID
                }
        } else {
            EmptyStateView {
                createNote()
            }
            .navigationTitle("CheatSheet")
        }
    }
    #endif

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
        .padding(AppDesign.contentPadding)
    }

    private func createNote() {
        showNotes(createNoteIfNeeded: false)
        let noteID = store.addNote()
        compactPath = [noteID]
    }

    private func showTrash() {
        store.searchText = ""
        store.enterTrash()
        isShowingTrash = true
        compactPath.removeAll()
    }

    private func showNotes(createNoteIfNeeded: Bool = true) {
        store.searchText = ""
        isShowingTrash = false
        store.leaveTrash(createNoteIfNeeded: createNoteIfNeeded)
        compactPath.removeAll()
    }

    private func widgetSetupHint(pinAction: @escaping () -> Void) -> some View {
        WidgetSetupHintView {
            pinAction()
        } hideAction: {
            showWidgetHints = false
        }
    }
}

private struct ContentToolbar: ToolbarContent {
    let isShowingTrash: Bool
    let selectedNoteIsArchived: Bool
    let createAction: () -> Void
    let archiveAction: () -> Void
    let toggleTrashAction: () -> Void

    var body: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                createAction()
            } label: {
                Label("New Note", systemImage: "square.and.pencil")
            }
            .accessibilityLabel("New Note")
            .accessibilityIdentifier("new-note-button")
        }

        ToolbarItemGroup(placement: .secondaryAction) {
            Button {
                toggleTrashAction()
            } label: {
                Label(isShowingTrash ? "Show Notes" : "Show Trash", systemImage: isShowingTrash ? "note.text" : "archivebox")
            }
            .accessibilityIdentifier("toggle-trash-button")

            Button(role: .destructive) {
                archiveAction()
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
            .disabled(selectedNoteIsArchived)
            .accessibilityIdentifier("move-to-trash-button")
        }
        #else
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                createAction()
            } label: {
                Label("New Note", systemImage: "plus")
            }
            .keyboardShortcut("n")

            Button(role: .destructive) {
                archiveAction()
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
            .help("Move the selected note to Trash for 30 days")
            .disabled(selectedNoteIsArchived)

            Button {
                toggleTrashAction()
            } label: {
                Label(isShowingTrash ? "Show Notes" : "Show Trash", systemImage: isShowingTrash ? "note.text" : "archivebox")
            }
            .help(isShowingTrash ? "Show Notes" : "Show Trash")
        }
        #endif
    }
}

private struct TrashEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Trash is empty")
                .font(.title3.weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WidgetSetupHintView: View {
    let pinAction: () -> Void
    let hideAction: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
        .padding(AppDesign.panelPadding)
        .background(.regularMaterial, in: .rect(cornerRadius: AppDesign.controlCornerRadius))
        .accessibilityElement(children: .contain)
    }

    private var horizontalLayout: some View {
        HStack(spacing: 12) {
            title

            message

            Spacer()

            actions
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            title
            message
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: some View {
        Label("Ready for the widget", systemImage: "pin")
            .font(.headline)
    }

    private var message: some View {
        Text("Pin this note to keep it available in your widget.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button("Hide", action: hideAction)

            Button("Pin", systemImage: "pin", action: pinAction)
                .glassCompatibleButtonStyle(prominent: true)
        }
    }
}

#if os(iOS)
private struct CompactNoteListView: View {
    @Bindable var store: NoteStore
    let isShowingTrash: Bool
    let addAction: () -> Void

    private var notes: [CheatSheetNote] {
        isShowingTrash ? store.filteredArchivedNotes : store.filteredNotes
    }

    var body: some View {
        Group {
            if notes.isEmpty {
                emptyState
            } else {
                List(notes) { note in
                    NavigationLink(value: note.id) {
                        SidebarNoteRow(note: note)
                    }
                }
                .listStyle(.insetGrouped)
                .accessibilityIdentifier("note-list")
            }
        }
        .navigationTitle(isShowingTrash ? "Trash" : "CheatSheet")
        .searchable(
            text: $store.searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: isShowingTrash ? "Search trash" : "Search notes"
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        if isShowingTrash {
            ContentUnavailableView {
                Label("Trash is empty", systemImage: "archivebox")
            } description: {
                Text("Deleted notes stay here for 30 days.")
            }
        } else {
            ContentUnavailableView {
                Label("No Notes", systemImage: "note.text.badge.plus")
            } description: {
                Text("Create a small checklist or cheat sheet to keep nearby.")
            } actions: {
                Button("Create Note", systemImage: "plus", action: addAction)
                    .glassCompatibleButtonStyle(prominent: true)
            }
        }
    }
}
#endif

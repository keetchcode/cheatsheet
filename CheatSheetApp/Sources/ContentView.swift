import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("showWidgetHints") private var showWidgetHints = true
    @State private var store = NoteStore()
    @State private var isShowingOnboarding = false

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            if let selectedNoteID = store.selectedNoteID,
               let note = store.binding(for: selectedNoteID) {
                VStack(alignment: .leading, spacing: AppDesign.panelSpacing) {
                    if showWidgetHints, !note.wrappedValue.isPinned {
                        widgetSetupHint {
                            store.setPinned(selectedNoteID)
                        }
                    }

                    EditorView(note: note) {
                        store.setPinned(selectedNoteID)
                    } deleteAction: {
                        store.deleteSelectedNote()
                    }
                }
                .padding(AppDesign.windowPadding)
            } else {
                EmptyStateView {
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
                    store.addNote()
                } label: {
                    Label("New Note", systemImage: "plus")
                }
                .keyboardShortcut("n")

                Button(role: .destructive) {
                    store.deleteSelectedNote()
                } label: {
                    Label("Delete Note", systemImage: "trash")
                }
                .disabled(store.notes.count <= 1)
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

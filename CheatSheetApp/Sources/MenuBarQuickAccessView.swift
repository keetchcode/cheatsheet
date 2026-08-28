#if os(macOS)
import AppKit
import SwiftUI

struct MenuBarQuickAccessScene: View {
    @Environment(\.openWindow) private var openWindow
    let store: NoteStore

    var body: some View {
        MenuBarQuickAccessView(store: store) {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

struct MenuBarQuickAccessView: View {
    @FocusState private var isQuickCaptureFocused: Bool
    let store: NoteStore
    let openMainWindowAction: () -> Void
    @State private var quickCaptureText = ""

    private var recentNotes: [CheatSheetNote] {
        Array(store.activeNotes.prefix(5))
    }

    private var trimmedQuickCaptureText: String {
        quickCaptureText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSaveQuickCapture: Bool {
        !trimmedQuickCaptureText.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            quickCapture

            Button {
                let noteID = store.addNote()
                store.selectedNoteID = noteID
                openMainWindow()
            } label: {
                Label("New Note", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .glassCompatibleButtonStyle(prominent: true)
            .controlSize(.large)
            .keyboardShortcut("n")
            .disabled(store.isPersistenceSuspended)
            .accessibilityHint("Creates a note and opens the CheatSheet window.")

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Notes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if recentNotes.isEmpty {
                    ContentUnavailableView("No Notes", systemImage: "note.text")
                        .frame(maxWidth: .infinity, minHeight: 96)
                } else {
                    ForEach(recentNotes) { note in
                        Button {
                            store.selectedNoteID = note.id
                            store.searchText = ""
                            openMainWindow()
                        } label: {
                            MenuBarNoteRow(note: note)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            Button {
                openMainWindow()
            } label: {
                Label("Open CheatSheet", systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }
            .glassCompatibleButtonStyle()
        }
        .padding(14)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "note.text")
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text("CheatSheet")
                .font(.headline)

            Spacer()

            if let pinnedNote = store.activeNotes.first(where: \.isPinned) {
                Label(pinnedNote.displayTitle, systemImage: "pin.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .help("Pinned: \(pinnedNote.displayTitle)")
            }
        }
    }

    private var quickCapture: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Quick Capture", systemImage: "square.and.pencil")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            TextEditor(text: $quickCaptureText)
                .font(.system(.body, design: .monospaced))
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .focused($isQuickCaptureFocused)
                .padding(8)
                .frame(minHeight: 78, idealHeight: 86, maxHeight: 104)
                .background(.quaternary.opacity(0.55), in: .rect(cornerRadius: 10))
                .overlay {
                    if quickCaptureText.isEmpty {
                        Text("Paste a command, shortcut, or reminder")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.top, 16)
                            .padding(.leading, 14)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Button("Clear") {
                    quickCaptureText = ""
                    isQuickCaptureFocused = true
                }
                .disabled(quickCaptureText.isEmpty)

                Spacer()

                Button {
                    saveQuickCapture()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .glassCompatibleButtonStyle(prominent: true)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canSaveQuickCapture || store.isPersistenceSuspended)
                .accessibilityHint("Saves this text as a new note without opening the main window.")
            }
        }
        .padding(10)
        .liquidGlassPanel(
            tint: CheatSheetPalette.blue.color,
            cornerRadius: 12
        )
    }

    private func saveQuickCapture() {
        let text = trimmedQuickCaptureText
        guard !text.isEmpty else { return }

        let title = Self.title(for: text)
        store.addNote(
            title: title,
            body: Self.body(for: text, title: title),
            tintHex: CheatSheetPalette.cyan.rawValue
        )
        quickCaptureText = ""
        isQuickCaptureFocused = true
    }

    private func openMainWindow() {
        openMainWindowAction()
    }

    private static func title(for text: String) -> String {
        let fallback = String(localized: "menuBar.quickCapture.defaultTitle", defaultValue: "Quick Note")
        guard let firstLine = text
            .split(whereSeparator: \.isNewline)
            .map({ String($0).trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) else {
            return fallback
        }

        let title = firstLine
            .trimmingCharacters(in: CharacterSet(charactersIn: "#-*` "))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return fallback }
        return String(title.prefix(64))
    }

    private static func body(for text: String, title: String) -> String {
        if text.contains(where: \.isNewline) || text.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
            return text
        }

        return "# \(title)\n- \(text)"
    }
}

private struct MenuBarNoteRow: View {
    let note: CheatSheetNote

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: note.tintHex))
                .frame(width: 9, height: 9)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(note.displayTitle)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Pinned")
                    }
                }

                Text(note.body.notePreviewLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
        .contentShape(.rect)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.quaternary.opacity(0.45), in: .rect(cornerRadius: 8))
    }
}
#endif

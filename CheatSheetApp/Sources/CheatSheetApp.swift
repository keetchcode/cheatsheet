import SwiftUI

@main
struct CheatSheetApp: App {
    @AppStorage("showMenuBarQuickAccess") private var showMenuBarQuickAccess = true
    @State private var store: NoteStore

    init() {
        CheatSheetLaunchEnvironment.applyLaunchOverrides()
        _store = State(wrappedValue: NoteStore(repository: CheatSheetLaunchEnvironment.makeRepository()))
    }

    var body: some Scene {
        #if os(macOS)
        WindowGroup("CheatSheet", id: "main") {
            ContentView(store: store)
                .frame(minWidth: AppDesign.windowMinimumWidth, minHeight: AppDesign.windowMinimumHeight)
        }
        .defaultSize(width: 980, height: 680)
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            SidebarCommands()
        }

        Settings {
            SettingsView()
        }

        MenuBarExtra("CheatSheet", systemImage: "note.text", isInserted: $showMenuBarQuickAccess) {
            MenuBarQuickAccessScene(store: store)
        }
        .menuBarExtraStyle(.window)
        #else
        WindowGroup {
            ContentView(store: store)
        }
        #endif
    }
}

import SwiftUI

@main
struct CheatSheetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
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
    }
}

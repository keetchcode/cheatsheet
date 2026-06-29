import SwiftUI

struct SettingsView: View {
    @AppStorage("showWidgetHints") private var showWidgetHints = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    #if os(macOS)
    @AppStorage("showMenuBarQuickAccess") private var showMenuBarQuickAccess = true
    #endif

    var body: some View {
        Form {
            #if os(macOS)
            Toggle("Show menu bar quick access", isOn: $showMenuBarQuickAccess)
            Text("Adds a CheatSheet icon to the menu bar for quick capture and recent notes.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
            #endif

            Toggle("Show widget setup hint", isOn: $showWidgetHints)
            Text("100% free and open source. Pin a note, then add the CheatSheet widget on supported platforms.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("Show onboarding next launch") {
                hasCompletedOnboarding = false
            }
        }
        .formStyle(.grouped)
        .scenePadding()
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 440)
    }
}

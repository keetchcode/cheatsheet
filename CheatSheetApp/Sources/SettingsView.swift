import SwiftUI

struct SettingsView: View {
    @AppStorage("showWidgetHints") private var showWidgetHints = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Form {
            Toggle("Show widget setup hint", isOn: $showWidgetHints)
            Text("100% free and open source. Pin a note in the main window, then add the CheatSheet widget from macOS widgets.")
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

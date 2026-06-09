import SwiftUI

struct OnboardingStartButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Start Writing", systemImage: "checkmark")
                .frame(minWidth: 130)
        }
        .glassCompatibleButtonStyle(prominent: true)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
    }
}

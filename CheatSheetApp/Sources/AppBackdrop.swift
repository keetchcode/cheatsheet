import SwiftUI

struct AppBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AppTheme.windowBase(for: colorScheme)

            LinearGradient(
                colors: AppTheme.windowGradient(for: colorScheme),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

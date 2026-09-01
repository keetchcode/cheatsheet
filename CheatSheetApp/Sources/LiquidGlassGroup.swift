import SwiftUI

struct LiquidGlassGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        #if os(macOS) || os(iOS)
        GlassEffectContainer(spacing: spacing) {
            content
        }
        #else
        content
        #endif
    }
}

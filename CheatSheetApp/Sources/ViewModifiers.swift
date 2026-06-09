import SwiftUI

extension View {
    @ViewBuilder
    func liquidGlassPanel(tint: Color, cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        modifier(LiquidGlassPanelModifier(tint: tint, cornerRadius: cornerRadius, interactive: interactive))
    }

    @ViewBuilder
    func glassCompatibleButtonStyle(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else if prominent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

private struct LiquidGlassPanelModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let tint: Color
    let cornerRadius: CGFloat
    let interactive: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if interactive {
                content.glassEffect(.regular.tint(tint.opacity(glassTintOpacity)).interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                content.glassEffect(.regular.tint(tint.opacity(glassTintOpacity)), in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content.background(
                AppTheme.glassFallbackFill(for: colorScheme, tint: tint),
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
        }
    }

    private var glassTintOpacity: Double {
        switch colorScheme {
        case .dark: interactive ? 0.16 : 0.12
        default: interactive ? 0.1 : 0.07
        }
    }
}

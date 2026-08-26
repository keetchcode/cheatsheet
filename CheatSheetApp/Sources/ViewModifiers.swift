import SwiftUI

extension View {
    @ViewBuilder
    func liquidGlassPanel(tint: Color, cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        modifier(LiquidGlassPanelModifier(tint: tint, cornerRadius: cornerRadius, interactive: interactive))
    }

    @ViewBuilder
    func glassCompatibleButtonStyle(prominent: Bool = false) -> some View {
        #if os(macOS)
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
        #elseif os(iOS)
        if #available(iOS 26.0, *) {
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
        #else
        if prominent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
        }
        #endif
    }

    /// A calm, readable surface for note content. Liquid Glass remains on
    /// controls and navigation, where its depth communicates interactivity.
    func noteContentSurface(tint: Color, cornerRadius: CGFloat) -> some View {
        modifier(NoteContentSurfaceModifier(tint: tint, cornerRadius: cornerRadius))
    }
}

private struct NoteContentSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let tint: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: .rect(cornerRadius: cornerRadius))
            .background(
                tint.opacity(colorScheme == .dark ? 0.16 : 0.09),
                in: .rect(cornerRadius: cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.primary.opacity(colorScheme == .dark ? 0.14 : 0.08), lineWidth: 1)
            }
    }
}

private struct LiquidGlassPanelModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let tint: Color
    let cornerRadius: CGFloat
    let interactive: Bool

    func body(content: Content) -> some View {
        #if os(macOS)
        if #available(macOS 26.0, *) {
            if interactive {
                content.glassEffect(.regular.tint(tint.opacity(glassTintOpacity)).interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                content.glassEffect(.regular.tint(tint.opacity(glassTintOpacity)), in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content.background(
                AppTheme.glassFallbackFill(for: colorScheme),
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
        }
        #elseif os(iOS)
        if #available(iOS 26.0, *) {
            if interactive {
                content.glassEffect(.regular.tint(tint.opacity(glassTintOpacity)).interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                content.glassEffect(.regular.tint(tint.opacity(glassTintOpacity)), in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content.background(
                AppTheme.glassFallbackFill(for: colorScheme),
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
        }
        #else
        content.background(
            AppTheme.glassFallbackFill(for: colorScheme),
            in: RoundedRectangle(cornerRadius: cornerRadius)
        )
        #endif
    }

    private var glassTintOpacity: Double {
        switch colorScheme {
        case .dark: interactive ? 0.16 : 0.12
        default: interactive ? 0.1 : 0.07
        }
    }
}

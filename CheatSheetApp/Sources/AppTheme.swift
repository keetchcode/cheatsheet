import SwiftUI

enum AppTheme {
    static func windowBase(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            Color(red: 0.08, green: 0.1, blue: 0.14)
        default:
            Color(red: 0.88, green: 0.91, blue: 0.94)
        }
    }

    static func windowGradient(for colorScheme: ColorScheme) -> [Color] {
        switch colorScheme {
        case .dark:
            [
                Color(red: 0.16, green: 0.2, blue: 0.28),
                Color(red: 0.1, green: 0.13, blue: 0.19),
                Color(red: 0.05, green: 0.07, blue: 0.11)
            ]
        default:
            [
                Color.white.opacity(0.94),
                Color(red: 0.91, green: 0.94, blue: 0.97),
                Color(red: 0.82, green: 0.86, blue: 0.9)
            ]
        }
    }

    static func glassFallbackFill(for colorScheme: ColorScheme) -> some ShapeStyle {
        switch colorScheme {
        case .dark:
            AnyShapeStyle(.regularMaterial)
        default:
            AnyShapeStyle(.ultraThinMaterial)
        }
    }
}

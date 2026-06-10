import SwiftUI

struct GlassPaletteSwatchButton: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    let swatch: CheatSheetPalette
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(swatch.color)
                .frame(width: 16, height: 16)
                .overlay {
                    selectedIndicator
                }
                .overlay {
                    Circle()
                        .stroke(borderStyle, lineWidth: isSelected ? 2 : 1)
                }
        }
        .buttonStyle(.plain)
        .frame(width: 26, height: 26)
        .contentShape(Rectangle())
        .accessibilityLabel("\(swatch.displayName) note color")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .help("Set \(swatch.displayName.lowercased()) note color")
    }

    @ViewBuilder
    private var selectedIndicator: some View {
        if isSelected {
            Image(systemName: differentiateWithoutColor ? "checkmark.circle.fill" : "checkmark")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(2)
                .background(.black.opacity(0.35), in: Circle())
        }
    }

    private var borderStyle: AnyShapeStyle {
        isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary.opacity(0.35))
    }
}

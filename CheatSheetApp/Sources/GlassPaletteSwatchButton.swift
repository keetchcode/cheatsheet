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
                .scaleEffect(isSelected ? 1.12 : 1)
                .overlay {
                    selectedIndicator
                }
                .overlay {
                    Circle()
                        .stroke(borderStyle, lineWidth: isSelected ? 2 : 1)
                }
        }
        .buttonStyle(.plain)
        .frame(width: hitTargetSize, height: hitTargetSize)
        .contentShape(Rectangle())
        .accessibilityLabel("\(swatch.displayName) note color")
        .accessibilityIdentifier("palette-\(swatch.rawValue.lowercased())")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .help("Set \(swatch.displayName.lowercased()) note color")
        .animation(.snappy(duration: 0.22), value: isSelected)
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

    private var hitTargetSize: CGFloat {
        #if os(iOS)
        AppDesign.minimumHitSize
        #else
        26
        #endif
    }
}

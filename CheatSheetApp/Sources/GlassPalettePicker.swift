import SwiftUI

struct GlassPalettePicker: View {
    @Binding var selection: String
    var onSelection: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CheatSheetPalette.allCases) { swatch in
                GlassPaletteSwatchButton(
                    swatch: swatch,
                    isSelected: selection == swatch.rawValue
                ) {
                    selection = swatch.rawValue
                    onSelection()
                }
            }
        }
        .padding(8)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }
}

import SwiftUI

struct GlassPalettePicker: View {
    @Binding var selection: String
    var onSelection: () -> Void = {}

    var body: some View {
        ViewThatFits(in: .horizontal) {
            swatchRow

            LazyVGrid(columns: compactColumns, alignment: .leading, spacing: 4) {
                swatches
            }
            .fixedSize()
        }
    }

    private var swatchRow: some View {
        HStack(spacing: 6) {
            swatches
        }
        .fixedSize()
    }

    private var compactColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(26), spacing: 6), count: 5)
    }

    private var swatches: some View {
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
}

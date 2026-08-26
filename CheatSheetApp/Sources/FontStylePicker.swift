import SwiftUI

struct FontStylePicker: View {
    @Binding var selection: CheatSheetFontStyle

    var body: some View {
        Menu {
            ForEach(CheatSheetFontStyle.allCases) { style in
                Button {
                    selection = style
                } label: {
                    Label {
                        Text(style.displayName)
                            .font(.system(.body, design: style.design))
                    } icon: {
                        Image(systemName: selection == style ? "checkmark" : "textformat")
                    }
                }
            }
        } label: {
            Label(selection.displayName, systemImage: "textformat")
        }
        .menuStyle(.button)
        .controlSize(.small)
        .help("Choose note font")
        .accessibilityLabel("Note font")
        .accessibilityValue(selection.displayName)
        .accessibilityIdentifier("font-style-picker")
    }
}

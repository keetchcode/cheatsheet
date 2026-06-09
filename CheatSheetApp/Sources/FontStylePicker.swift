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
        .help("Choose widget font")
        .accessibilityLabel("Widget font")
        .accessibilityValue(selection.displayName)
    }
}

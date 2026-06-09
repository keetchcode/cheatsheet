import SwiftUI
import WidgetKit

struct CheatSheetWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: CheatSheetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: family.verticalSpacing) {
            HStack(spacing: 8) {
                Image(systemName: "text.page.fill")
                    .font(.headline)
                    .foregroundStyle(renderingMode == .fullColor ? entry.note.tint : .white)
                    .widgetAccentable()
                    .accessibilityHidden(true)

                Text(entry.note.displayTitle)
                    .font(family.titleFont(for: entry.note.fontStyle))
                    .foregroundStyle(primaryTextStyle)
                    .lineLimit(family == .systemSmall ? 1 : 2)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: family.lineSpacing) {
                ForEach(entry.note.displayLines.prefix(family.lineLimit)) { line in
                    WidgetLineView(line: line, fontStyle: entry.note.fontStyle)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(family.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            widgetBackground
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var widgetBackground: some View {
        if renderingMode == .fullColor {
            switch colorScheme {
            case .dark:
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.14, blue: 0.18),
                        Color(red: 0.05, green: 0.06, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            default:
                LinearGradient(
                    colors: [
                        Color(red: 0.94, green: 0.97, blue: 1.0),
                        Color(red: 0.82, green: 0.89, blue: 0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            Color.clear
        }
    }

    private var primaryTextStyle: Color {
        renderingMode == .fullColor ? .primary : .white
    }
}

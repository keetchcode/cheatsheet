import SwiftUI
import WidgetKit

struct CheatSheetWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: CheatSheetEntry

    var body: some View {
        Group {
            if let note = entry.note {
                noteView(note)
            } else {
                emptyState
            }
        }
        .padding(family.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            widgetBackground
        }
        .accessibilityElement(children: .combine)
    }

    private func noteView(_ note: CheatSheetNote) -> some View {
        VStack(alignment: .leading, spacing: family.verticalSpacing) {
            header(title: note.displayTitle, systemImage: "text.page.fill", tint: note.tint, fontStyle: note.fontStyle)

            VStack(alignment: .leading, spacing: family.lineSpacing) {
                ForEach(note.displayLines(limit: family.lineLimit)) { line in
                    WidgetLineView(line: line, fontStyle: note.fontStyle)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: family.verticalSpacing) {
            header(
                title: String(localized: "widget.emptyState.title", defaultValue: "No Widget Note"),
                systemImage: "note.text.badge.plus",
                tint: CheatSheetPalette.blue.color,
                fontStyle: .rounded
            )

            Text("Pin or create a note in CheatSheet to show it here.")
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(primaryTextStyle)
                .lineLimit(family == .systemSmall ? 3 : 5)

            Spacer(minLength: 0)
        }
    }

    private func header(
        title: String,
        systemImage: String,
        tint: Color,
        fontStyle: CheatSheetFontStyle
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(renderingMode == .fullColor ? tint : .white)
                .widgetAccentable()
                .accessibilityHidden(true)

            Text(title)
                .font(family.titleFont(for: fontStyle))
                .foregroundStyle(primaryTextStyle)
                .lineLimit(family == .systemSmall ? 1 : 2)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)
        }
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

import SwiftUI
import WidgetKit

struct WidgetLineView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let line: DisplayLine
    let fontStyle: CheatSheetFontStyle

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: line.isComplete ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(iconStyle)
                .opacity(line.isTask ? 1 : 0.35)
                .accessibilityHidden(true)

            Text(line.text)
                .font(.system(.caption, design: fontStyle.design).weight(line.isHeading ? .semibold : .regular))
                .foregroundStyle(textStyle)
                .strikethrough(line.isComplete)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard line.isTask else { return line.text }
        return line.isComplete
            ? String(localized: "checklist.line.complete", defaultValue: "Complete, \(line.text)")
            : String(localized: "checklist.line.incomplete", defaultValue: "Incomplete, \(line.text)")
    }

    private var textStyle: Color {
        guard renderingMode == .fullColor else {
            return line.isComplete ? .white.opacity(0.9) : .white
        }

        return line.isComplete ? .secondary : .primary
    }

    private var iconStyle: Color {
        guard renderingMode == .fullColor else {
            return line.isComplete ? .white : .white.opacity(0.78)
        }

        return line.isComplete ? .green : .secondary
    }
}

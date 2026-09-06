import SwiftUI

struct ChecklistLineView: View {
    let text: String
    let isTask: Bool
    let isComplete: Bool
    let isHeading: Bool
    let fontDesign: Font.Design

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(isComplete ? .green : .secondary)
                .opacity(isTask ? 1 : 0.4)
                .accessibilityHidden(true)

            Text(text)
                .font(.system(.callout, design: fontDesign).weight(isHeading ? .semibold : .regular))
                .foregroundStyle(isComplete ? .secondary : .primary)
                .strikethrough(isComplete)
                .lineLimit(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard isTask else { return text }
        return isComplete
            ? String(localized: "checklist.line.complete", defaultValue: "Complete, \(text)")
            : String(localized: "checklist.line.incomplete", defaultValue: "Incomplete, \(text)")
    }
}

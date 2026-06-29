import Foundation

public struct DisplayLine: Identifiable, Hashable, Sendable {
    public let id: Int
    public let text: String
    public let isTask: Bool
    public let isComplete: Bool
    public let isHeading: Bool
}

public extension CheatSheetNote {
    var displayLines: [DisplayLine] {
        displayLines(limit: .max)
    }

    func displayLines(limit: Int) -> [DisplayLine] {
        guard limit > 0 else { return [] }

        var lines: [DisplayLine] = []

        for (index, rawLine) in body
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .enumerated() {
            guard lines.count < limit else { break }
            let parsed = String(rawLine).parsedChecklistLine
            guard !parsed.text.isEmpty else { continue }
            lines.append(DisplayLine(
                id: index,
                text: parsed.text,
                isTask: parsed.isTask,
                isComplete: parsed.isComplete,
                isHeading: parsed.isHeading
            ))
        }

        return lines
    }
}

public extension String {
    var notePreviewLine: String {
        for rawLine in split(whereSeparator: \.isNewline) {
            let text = String(rawLine).parsedChecklistLine.text
            if !text.isEmpty {
                return text
            }
        }

        return "Empty note"
    }

    var parsedChecklistLine: (text: String, isTask: Bool, isComplete: Bool, isHeading: Bool) {
        var line = trimmingCharacters(in: .whitespacesAndNewlines)
        var isComplete = false
        var isTask = false
        var isHeading = false

        if line.hasPrefix("#") {
            isHeading = true
            line = line.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        }

        let markers = ["- [x] ", "* [x] ", "[x] ", "- [X] ", "* [X] ", "[X] "]
        if let marker = markers.first(where: { line.hasPrefix($0) }) {
            isComplete = true
            isTask = true
            line.removeFirst(marker.count)
        } else {
            let openMarkers = ["- [ ] ", "* [ ] ", "[ ] ", "- ", "* "]
            if let marker = openMarkers.first(where: { line.hasPrefix($0) }) {
                isTask = true
                line.removeFirst(marker.count)
            }
        }

        return (line.trimmingCharacters(in: .whitespacesAndNewlines), isTask, isComplete, isHeading)
    }
}

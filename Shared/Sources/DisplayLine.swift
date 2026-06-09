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
        body
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .enumerated()
            .compactMap { index, rawLine in
                let parsed = String(rawLine).parsedChecklistLine
                guard !parsed.text.isEmpty else { return nil }
                return DisplayLine(
                    id: index,
                    text: parsed.text,
                    isTask: parsed.isTask,
                    isComplete: parsed.isComplete,
                    isHeading: parsed.isHeading
                )
            }
    }
}

public extension String {
    var notePreviewLine: String {
        split(whereSeparator: \.isNewline)
            .map(String.init)
            .map { $0.parsedChecklistLine.text }
            .first { !$0.isEmpty } ?? "Empty note"
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

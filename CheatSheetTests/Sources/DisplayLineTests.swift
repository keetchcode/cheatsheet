import Testing

struct DisplayLineTests {
    @Test func parsesHeadingLine() {
        let parsed = "# Git Flow".parsedChecklistLine

        #expect(parsed.text == "Git Flow")
        #expect(parsed.isHeading)
        #expect(parsed.isTask == false)
        #expect(parsed.isComplete == false)
    }

    @Test func headingKeepsTrailingHashInLanguageNames() {
        // Regression: trimmingCharacters(in:) trimmed both ends, so "# C#"
        // rendered as "C" in both the editor and the widget.
        #expect("# C#".parsedChecklistLine.text == "C#")
        #expect("# F#".parsedChecklistLine.text == "F#")
        #expect("# C# vs F#".parsedChecklistLine.text == "C# vs F#")
    }

    @Test func headingStripsOnlyLeadingHashes() {
        let parsed = "## Objective-C".parsedChecklistLine

        #expect(parsed.text == "Objective-C")
        #expect(parsed.isHeading)
        #expect(parsed.isTask == false)
    }

    @Test func parsesCompleteTaskLine() {
        let parsed = "- [x] Run build".parsedChecklistLine

        #expect(parsed.text == "Run build")
        #expect(parsed.isTask)
        #expect(parsed.isComplete)
        #expect(parsed.isHeading == false)
    }

    @Test func parsesPlainBulletAsOpenTask() {
        let parsed = "- Add tests".parsedChecklistLine

        #expect(parsed.text == "Add tests")
        #expect(parsed.isTask)
        #expect(parsed.isComplete == false)
        #expect(parsed.isHeading == false)
    }

    @Test func parsesPlainLineAsReminderText() {
        let parsed = "Plain lines show as simple reminder text.".parsedChecklistLine

        #expect(parsed.text == "Plain lines show as simple reminder text.")
        #expect(parsed.isTask == false)
        #expect(parsed.isComplete == false)
        #expect(parsed.isHeading == false)
    }

    @Test func displayLinesSkipEmptyLinesAndPreserveSourceLineIDs() throws {
        let note = CheatSheetNote(
            title: "Release",
            body: """
            # Release

            - [ ] Run tests
            - Ship
            """
        )

        let heading = try #require(note.displayLines.first)
        let task = try #require(note.displayLines.dropFirst().first)

        #expect(note.displayLines.count == 3)
        #expect(heading.id == 0)
        #expect(heading.text == "Release")
        #expect(task.id == 2)
        #expect(task.text == "Run tests")
    }

    @Test func previewLineFallsBackForEmptyNotes() {
        #expect("\n  \n".notePreviewLine == "Empty note")
    }

    @Test func displayLinesCanStopAfterRequestedLimit() {
        let note = CheatSheetNote(
            title: "Limit",
            body: """
            # First
            - Second
            - Third
            """
        )

        let lines = note.displayLines(limit: 2)

        #expect(lines.map(\.text) == ["First", "Second"])
    }
}

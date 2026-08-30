import Foundation
import Testing

/// Exercises every localized call site's Swift-side logic in process. This unit
/// test target does not embed `Resources/` (see `project.yml`), so `String(localized:)`
/// always resolves to its English `defaultValue` fallback here -- exactly the path
/// a real install takes if a translation is ever missing from the bundle. These
/// tests lock in that the fallback text is correct, non-empty, and that singular/
/// plural and interpolated call sites don't crash. Catalog-level checks (every key
/// translated into Spanish, matching %@ / %lld placeholders between languages, no
/// stable key leaking into the UI untranslated) live in `Scripts/verify-localization.sh`,
/// which runs against the `.xcstrings` files directly and is wired into CI --
/// unlike this test target, it isn't sandboxed away from the checkout on disk.
struct LocalizationTests {
    @Test func noteDisplayTitleFallsBackToLocalizedPlaceholderWhenBlank() {
        let blank = CheatSheetNote(title: "   ", body: "- test")
        let whitespaceOnly = CheatSheetNote(title: "\n\t", body: "- test")
        let real = CheatSheetNote(title: "Deploy Steps", body: "- test")

        #expect(blank.displayTitle == "Untitled Note")
        #expect(whitespaceOnly.displayTitle == "Untitled Note")
        #expect(real.displayTitle == "Deploy Steps")
    }

    @Test func notePreviewLineFallsBackToLocalizedPlaceholderWhenEmpty() {
        #expect("".notePreviewLine == "Empty note")
        #expect("\n  \n".notePreviewLine == "Empty note")
        #expect("- Ship it".notePreviewLine == "Ship it")
    }

    @Test func trashStatusTextSingularAndPluralBranchesAreDistinctAndNonCrashing() {
        let archivedAt = Date(timeIntervalSince1970: 1_000)
        let note = CheatSheetNote(title: "Archived", body: "- demo", archivedAt: archivedAt)

        let thirtyDays = note.trashStatusText(referenceDate: archivedAt)
        let oneDay = note.trashStatusText(referenceDate: archivedAt.addingTimeInterval(29 * NoteTrashPolicy.dayInterval + 1))
        let readyForDeletion = note.trashStatusText(referenceDate: archivedAt.addingTimeInterval(NoteTrashPolicy.retentionInterval))
        let notArchived = CheatSheetNote(title: "Active", body: "- demo").trashStatusText

        #expect(thirtyDays == "Deletes automatically in 30 days.")
        #expect(oneDay == "Deletes automatically in 1 day.")
        #expect(oneDay != thirtyDays, "Singular and plural day counts must render distinct text.")
        #expect(readyForDeletion == "This note is ready for permanent deletion.")
        #expect(notArchived == "This note is not in Trash.")
    }

    @Test func everyStorageErrorHasANonEmptyLocalizedDescription() {
        let identifier = "group.com.example.test"
        let errors: [CheatSheetStorageError] = [
            .appGroupUnavailable(identifier),
            .repositoryUnavailable,
            .noteEncodingFailed,
            .noteDecodingFailed,
            .widgetSnapshotDecodingFailed,
            .widgetSnapshotEncodingFailed
        ]

        for error in errors {
            #expect(error.errorDescription?.isEmpty == false, "\(error) must have a non-empty localized description")
        }

        #expect(CheatSheetStorageError.appGroupUnavailable(identifier).errorDescription?.contains(identifier) == true)
    }

    @Test func everyColorNameIsNonEmptyAndDistinct() {
        let names = CheatSheetPalette.allCases.map(\.displayName)

        #expect(names.allSatisfy { !$0.isEmpty })
        #expect(Set(names).count == names.count, "Color names must be distinct so the picker isn't ambiguous.")
    }

    @Test func everyFontStyleNameIsNonEmptyAndDistinct() {
        let names = CheatSheetFontStyle.allCases.map(\.displayName)

        #expect(names.allSatisfy { !$0.isEmpty })
        #expect(Set(names).count == names.count, "Font style names must be distinct so the picker isn't ambiguous.")
    }

    @Test func starterNotesHaveNonEmptyTitlesAndBodies() {
        for note in CheatSheetNote.starterNotes {
            #expect(!note.title.isEmpty)
            #expect(!note.body.isEmpty)
            #expect(note.displayLines.isEmpty == false, "Starter note body should still parse into displayable lines.")
        }
    }

    @Test func defaultNoteTitleIsStableAndNonEmpty() {
        #expect(NoteStore.defaultNoteTitle == "New Cheat Sheet")
    }

    @Test func screenshotDemoContentIsWellFormed() {
        let notes = ScreenshotDemoContent.notes

        #expect(notes.count == 8)
        #expect(notes.filter(\.isPinned).count == 1, "Exactly one demo note should be pinned so the widget capture is unambiguous.")
        #expect(Set(notes.map(\.title)).count == notes.count, "Demo note titles must be distinct.")
        #expect(Set(notes.map(\.tintHex)).count == notes.count, "Demo notes should each use a distinct palette color to show organization.")

        for note in notes {
            #expect(!note.title.isEmpty)
            #expect(!note.body.isEmpty)
            #expect(note.displayLines.isEmpty == false, "Demo note body should parse into displayable lines.")
        }
    }
}

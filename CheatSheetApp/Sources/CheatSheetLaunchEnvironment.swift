import Foundation

/// Launch-argument hooks used by UI tests.
///
/// UI tests drive the real app process, so without these the suite would read
/// and write the shared App Group store — the developer's (or CI machine's)
/// actual notes. Test mode swaps in an in-memory SwiftData container so runs are
/// isolated, deterministic, and repeatable.
enum CheatSheetLaunchEnvironment {
    static let uiTestingArgument = "-cheatsheet-ui-testing"
    static let resetOnboardingArgument = "-cheatsheet-reset-onboarding"
    static let skipOnboardingArgument = "-cheatsheet-skip-onboarding"
    static let showTrashArgument = "-cheatsheet-show-trash"
    /// Seeds `ScreenshotDemoContent.notes` into the same isolated in-memory
    /// store UI tests use, so App Store captures are reproducible without
    /// manual tapping and never touch a real device's notes.
    static let seedScreenshotDemoArgument = "-cheatsheet-seed-screenshot-demo"

    static var isUITesting: Bool {
        arguments.contains(uiTestingArgument)
    }

    /// Starts the app already showing Trash. The toggle lives in the toolbar's
    /// secondary-action group, which iOS may collapse into a system "More"
    /// overflow whose menu rows do not resolve by accessibility identifier --
    /// so a test that only needs to read Trash content should not have to
    /// drive that chrome. Gated on UI testing so it cannot fire in production.
    static var isStartingInTrash: Bool {
        isUITesting && arguments.contains(showTrashArgument)
    }

    static var isSeedingScreenshotDemo: Bool {
        arguments.contains(seedScreenshotDemoArgument)
    }

    private static var arguments: [String] {
        ProcessInfo.processInfo.arguments
    }

    /// Applies launch-argument overrides. Call before any view reads
    /// `@AppStorage`, otherwise onboarding state is non-deterministic between runs.
    static func applyLaunchOverrides() {
        guard isUITesting else { return }

        if arguments.contains(resetOnboardingArgument) {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }

        if arguments.contains(skipOnboardingArgument) {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
    }

    static func makeRepository() -> any CheatSheetNoteRepository {
        guard isUITesting else {
            return CheatSheetNoteRepositoryFactory.live()
        }

        do {
            let repository = SwiftDataCheatSheetNoteRepository(
                container: try SwiftDataCheatSheetNoteRepository.makeInMemoryContainer()
            )

            if isSeedingScreenshotDemo {
                try repository.saveNotes(ScreenshotDemoContent.notes)
            }

            return repository
        } catch {
            return UnavailableCheatSheetNoteRepository()
        }
    }
}

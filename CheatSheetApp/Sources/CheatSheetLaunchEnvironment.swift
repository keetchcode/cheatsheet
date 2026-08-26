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
    static let screenshotModeArgument = "-cheatsheet-screenshot-mode"
    /// Replaces the store contents with the App Store screenshot note set.
    /// Debug builds only, so a shipping app can never be talked into it.
    static let demoContentArgument = "-cheatsheet-demo-content"

    static var isUITesting: Bool {
        arguments.contains(uiTestingArgument)
    }

    private static var arguments: [String] {
        ProcessInfo.processInfo.arguments
    }

    /// Onboarding overrides apply under UI testing, and in Debug builds when
    /// demo content is requested — the screenshot run drives the real store and
    /// still needs a deterministic first screen.
    private static var allowsOnboardingOverrides: Bool {
        if isUITesting { return true }

        #if DEBUG
        return arguments.contains(demoContentArgument)
        #else
        return false
        #endif
    }

    /// Applies launch-argument overrides. Call before any view reads
    /// `@AppStorage`, otherwise onboarding state is non-deterministic between runs.
    static func applyLaunchOverrides() {
        guard allowsOnboardingOverrides else { return }

        if arguments.contains(resetOnboardingArgument) {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }

        if arguments.contains(skipOnboardingArgument) {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
    }

    static func makeRepository() -> any CheatSheetNoteRepository {
        let repository = makeBaseRepository()
        seedDemoContentIfRequested(into: repository)
        return repository
    }

    private static func makeBaseRepository() -> any CheatSheetNoteRepository {
        guard isUITesting else {
            return CheatSheetNoteRepositoryFactory.live()
        }

        do {
            return SwiftDataCheatSheetNoteRepository(
                container: try SwiftDataCheatSheetNoteRepository.makeInMemoryContainer()
            )
        } catch {
            return UnavailableCheatSheetNoteRepository()
        }
    }

    /// Seeds the App Store screenshot notes so captures show a populated app
    /// instead of the two starter notes. Compiled out of Release builds.
    private static func seedDemoContentIfRequested(into repository: any CheatSheetNoteRepository) {
        #if DEBUG
        guard arguments.contains(demoContentArgument),
              arguments.contains(screenshotModeArgument) || isUITesting else { return }

        do {
            try repository.saveNotes(CheatSheetDemoContent.notes)
        } catch {
            fatalError("Could not seed deterministic screenshot content: \(error.localizedDescription)")
        }
        #endif
    }
}

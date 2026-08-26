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

    static var isUITesting: Bool {
        arguments.contains(uiTestingArgument)
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
            return SwiftDataCheatSheetNoteRepository(
                container: try SwiftDataCheatSheetNoteRepository.makeInMemoryContainer()
            )
        } catch {
            return UnavailableCheatSheetNoteRepository()
        }
    }
}

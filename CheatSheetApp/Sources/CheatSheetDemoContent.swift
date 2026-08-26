#if DEBUG
import Foundation

/// Note set used for App Store screenshot runs.
///
/// Fixed identifiers and timestamps keep captures byte-stable between runs, so
/// re-shooting one screen does not silently change the others. Debug-only: this
/// content must never reach a shipping build.
enum CheatSheetDemoContent {
    static let notes: [CheatSheetNote] = [
        note(
            id: 1,
            title: "Git Rescue",
            tint: .indigo,
            isPinned: true,
            daysAgo: 0,
            body: """
            - git switch -c fix/name
            - git commit --amend --no-edit
            - git rebase -i main
            - git reset --soft HEAD~1
            - git stash -u
            - git log --oneline --graph
            - git push --force-with-lease
            # Before you push
            - [x] Pull, then rebase
            - [ ] Never force-push main
            """
        ),
        note(
            id: 2,
            title: "Ship Checklist",
            tint: .mint,
            daysAgo: 1,
            body: """
            - [x] Bump the build number
            - [x] Run the full test suite
            - [x] Check the privacy manifest
            - [ ] Refresh App Store screenshots
            - [ ] git tag v1.1
            - [ ] Archive and upload
            - [ ] Submit for review
            """
        ),
        note(
            id: 3,
            title: "Swift Concurrency",
            tint: .violet,
            daysAgo: 2,
            body: """
            - @MainActor on anything UI
            - Task { } to call async from sync
            - await MainActor.run { }
            - Actors isolate mutable state
            - Check Task.isCancelled in loops
            - TaskGroup over DispatchGroup
            """
        ),
        note(
            id: 4,
            title: "Docker Cleanup",
            tint: .amber,
            daysAgo: 3,
            body: """
            - docker ps -a
            - docker compose down -v
            - docker image prune -af
            - docker system df
            - docker logs -f api
            """
        ),
        note(
            id: 5,
            title: "Vim Motions",
            tint: .coral,
            daysAgo: 4,
            body: """
            - ciw change inside word
            - daw delete a word
            - gg=G reindent the file
            - :%s/old/new/g
            - Ctrl-o jump back
            """
        ),
        note(
            id: 6,
            title: "zsh + Homebrew",
            tint: .cyan,
            daysAgo: 5,
            body: """
            - brew bundle dump --force
            - brew cleanup --prune=all
            - brew doctor
            - source ~/.zshrc
            """
        ),
        note(
            id: 7,
            title: "Xcode Shortcuts",
            tint: .rose,
            daysAgo: 6,
            body: """
            - Cmd-Shift-O open quickly
            - Cmd-Shift-K clean build folder
            - Ctrl-Cmd-Left go back
            - Cmd-Ctrl-E rename in scope
            """
        ),
        note(
            id: 8,
            title: "HTTP Status Codes",
            tint: .lime,
            daysAgo: 7,
            body: """
            - 201 created, 204 no content
            - 401 unauthenticated
            - 403 authenticated, not allowed
            - 409 conflict
            - 422 validation failed
            """
        )
    ]

    private static func note(
        id: Int,
        title: String,
        tint: CheatSheetPalette,
        isPinned: Bool = false,
        daysAgo: Int,
        body: String
    ) -> CheatSheetNote {
        CheatSheetNote(
            id: uuid(id),
            title: title,
            body: body,
            tintHex: tint.rawValue,
            isPinned: isPinned,
            updatedAt: referenceDate.addingTimeInterval(TimeInterval(-daysAgo) * 86_400)
        )
    }

    private static func uuid(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "C4EA7500-0000-4000-A000-%012d", index)) ?? UUID()
    }

    /// 2026-01-15 09:41 UTC — Apple's traditional keynote clock.
    private static let referenceDate = Date(timeIntervalSince1970: 1_768_469_460)
}
#endif

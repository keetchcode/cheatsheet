import Foundation

/// Deterministic demo content for App Store screenshot capture only.
///
/// Real starter content (`CheatSheetNote.starterNotes`) stays small and
/// first-run-appropriate. Screenshot captures need a fuller, varied sidebar
/// to show organization and color variety honestly — this is real,
/// representative developer reference content (generic git/docker/vim/HTTP
/// facts, nothing app-specific or fabricated), never used outside a launch
/// gated by `-cheatsheet-seed-screenshot-demo`.
enum ScreenshotDemoContent {
    static let notes: [CheatSheetNote] = [
        CheatSheetNote(
            title: "Git Rescue",
            body: """
            # Git Rescue
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
            """,
            tintHex: CheatSheetPalette.indigo.rawValue,
            isPinned: true
        ),
        CheatSheetNote(
            title: "Ship Checklist",
            body: """
            # Ship Checklist
            - [ ] Bump the build number
            - [ ] Update release notes
            - [ ] Run the full test suite
            - [ ] Archive in Release configuration
            - [ ] Verify entitlements match project.yml
            - [ ] Tag the release commit
            """,
            tintHex: CheatSheetPalette.mint.rawValue
        ),
        CheatSheetNote(
            title: "Swift Concurrency",
            body: """
            # Swift Concurrency
            - @MainActor on anything UI
            - actor for shared mutable state
            - Task { } for fire-and-forget work
            - Task.detached only to escape actor context
            - await MainActor.run { } from background work
            - Cancel long tasks in deinit
            """,
            tintHex: CheatSheetPalette.violet.rawValue
        ),
        CheatSheetNote(
            title: "Docker Cleanup",
            body: """
            # Docker Cleanup
            - docker ps -a
            - docker system prune -a
            - docker volume prune
            - docker image prune -a
            - docker compose down -v
            - docker stats
            """,
            tintHex: CheatSheetPalette.amber.rawValue
        ),
        CheatSheetNote(
            title: "Vim Motions",
            body: """
            # Vim Motions
            - ciw change inside word
            - dd delete line
            - yy yank line
            - p paste after
            - gg top of file
            - G bottom of file
            - :%s/old/new/g replace all
            """,
            tintHex: CheatSheetPalette.coral.rawValue
        ),
        CheatSheetNote(
            title: "zsh + Homebrew",
            body: """
            # zsh + Homebrew
            - brew bundle dump --force
            - brew bundle install
            - brew doctor
            - brew cleanup
            - brew list --formula
            - source ~/.zshrc
            """,
            tintHex: CheatSheetPalette.cyan.rawValue
        ),
        CheatSheetNote(
            title: "Xcode Shortcuts",
            body: """
            # Xcode Shortcuts
            - Cmd-Shift-O open quickly
            - Cmd-Shift-J reveal in navigator
            - Cmd-Ctrl-Up switch header/source
            - Cmd-/ toggle comment
            - Cmd-Ctrl-E edit all in scope
            - Cmd-B build
            """,
            tintHex: CheatSheetPalette.rose.rawValue
        ),
        CheatSheetNote(
            title: "HTTP Status Codes",
            body: """
            # HTTP Status Codes
            - 200 OK
            - 201 created, 204 no content
            - 301 moved permanently
            - 400 bad request
            - 401 unauthorized
            - 404 not found
            - 500 internal server error
            """,
            tintHex: CheatSheetPalette.lime.rawValue
        )
    ]
}

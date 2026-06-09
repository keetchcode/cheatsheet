import Foundation
import SwiftUI

public let cheatSheetAppGroupID = "HD39MR492X.com.wesleykeetch.CheatSheet"

public struct CheatSheetNote: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var body: String
    public var tintHex: String
    public var fontStyleRawValue: String?
    public var isPinned: Bool
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        body: String,
        tintHex: String = "4B88FF",
        fontStyle: CheatSheetFontStyle = .monospaced,
        isPinned: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.tintHex = tintHex
        self.fontStyleRawValue = fontStyle.rawValue
        self.isPinned = isPinned
        self.updatedAt = updatedAt
    }

    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Note" : trimmed
    }

    public var fontStyle: CheatSheetFontStyle {
        get {
            guard let fontStyleRawValue,
                  let style = CheatSheetFontStyle(rawValue: fontStyleRawValue) else {
                return .monospaced
            }

            return style
        }
        set {
            fontStyleRawValue = newValue.rawValue
        }
    }
}

public extension CheatSheetNote {
    static let starterNotes: [CheatSheetNote] = [
        CheatSheetNote(
            title: "Git Flow",
            body: """
            # Git Flow
            - git status
            - git switch -c feature/name
            - git add .
            - git commit -m "Describe change"
            - git push -u origin HEAD
            - gh pr create --draft
            """,
            tintHex: "4B88FF",
            isPinned: true
        ),
        CheatSheetNote(
            title: "SwiftUI Checks",
            body: """
            # SwiftUI Checks
            - Keep @State private
            - Use stable ForEach identity
            - Use Button for click targets
            - Add accessibility labels
            - Run build before handoff
            """,
            tintHex: "45C7C4"
        )
    ]
}

public enum CheatSheetPalette: String, CaseIterable, Identifiable, Sendable {
    case blue = "4B88FF"
    case cyan = "45C7C4"
    case violet = "8B7CFF"
    case mint = "59C979"
    case graphite = "5C6470"

    public var id: String { rawValue }

    public var color: Color {
        Color(hex: rawValue)
    }

    public var displayName: String {
        switch self {
        case .blue: "Blue"
        case .cyan: "Cyan"
        case .violet: "Violet"
        case .mint: "Mint"
        case .graphite: "Graphite"
        }
    }
}

public enum CheatSheetFontStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case monospaced
    case system
    case rounded
    case serif

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .monospaced: "Mono"
        case .system: "System"
        case .rounded: "Rounded"
        case .serif: "Serif"
        }
    }

    public var design: Font.Design {
        switch self {
        case .monospaced: .monospaced
        case .system: .default
        case .rounded: .rounded
        case .serif: .serif
        }
    }
}

public extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

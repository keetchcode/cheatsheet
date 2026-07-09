import Foundation
import SwiftUI

public enum CheatSheetAppGroupID {
    public static let iOS = "group.com.wesleykeetch.wesleycheatsheet"
    public static let macOS = "HD39MR492X.com.wesleykeetch.wesleycheatsheet"

    public static var current: String {
        #if os(iOS)
        iOS
        #else
        macOS
        #endif
    }
}

public let cheatSheetAppGroupID = CheatSheetAppGroupID.current

public struct CheatSheetNote: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var body: String
    public var tintHex: String
    public var fontStyleRawValue: String?
    public var isPinned: Bool
    public var updatedAt: Date
    public var archivedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        body: String,
        tintHex: String = "4B88FF",
        fontStyle: CheatSheetFontStyle = .monospaced,
        isPinned: Bool = false,
        updatedAt: Date = .now,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.tintHex = CheatSheetPalette.normalizedHex(tintHex)
        self.fontStyleRawValue = fontStyle.rawValue
        self.isPinned = isPinned
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case tintHex
        case fontStyleRawValue
        case isPinned
        case updatedAt
        case archivedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        tintHex = CheatSheetPalette.normalizedHex(try container.decodeIfPresent(String.self, forKey: .tintHex))
        fontStyleRawValue = try container.decodeIfPresent(String.self, forKey: .fontStyleRawValue)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(CheatSheetPalette.normalizedHex(tintHex), forKey: .tintHex)
        try container.encodeIfPresent(fontStyleRawValue, forKey: .fontStyleRawValue)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(archivedAt, forKey: .archivedAt)
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

    public var isArchived: Bool {
        archivedAt != nil
    }
}

public extension CheatSheetNote {
    static let starterNotes: [CheatSheetNote] = [
        CheatSheetNote(
            title: "Widget Formatting Demo",
            body: """
            # Widget Formatting Demo
            Plain lines show as simple reminder text.
            - Bullets become quick checklist rows.
            - [ ] Open tasks use an empty circle.
            - [x] Finished tasks use a checkmark.
            # Tips
            - Pin one note to show it in the widget.
            - Pick a color and font above the editor.
            - Short lines read best on the desktop.
            """,
            tintHex: CheatSheetPalette.indigo.rawValue,
            isPinned: true
        ),
        CheatSheetNote(
            title: "Git Flow",
            body: """
            # Git Flow
            - git status
            - git switch -c feature/name
            - git add .
            - git commit -m "Describe change"
            - git push -u origin HEAD
            """,
            tintHex: CheatSheetPalette.cyan.rawValue
        )
    ]
}

public extension Array where Element == CheatSheetNote {
    var widgetDisplayNote: CheatSheetNote? {
        first { $0.isPinned && !$0.isArchived } ?? first { !$0.isArchived }
    }
}

public enum CheatSheetPalette: String, CaseIterable, Identifiable, Sendable {
    case blue = "4B88FF"
    case cyan = "45C7C4"
    case violet = "8B7CFF"
    case mint = "59C979"
    case lime = "8FBF3F"
    case amber = "D99A2B"
    case coral = "E86F51"
    case rose = "E85D75"
    case indigo = "5D6BFF"
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
        case .lime: "Lime"
        case .amber: "Amber"
        case .coral: "Coral"
        case .rose: "Rose"
        case .indigo: "Indigo"
        case .graphite: "Graphite"
        }
    }

    public static func normalizedHex(_ hex: String?) -> String {
        var stripped = (hex ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if stripped.hasPrefix("#") {
            stripped.removeFirst()
        }

        guard stripped.count == 6,
              stripped.allSatisfy({ $0.hexDigitValue != nil }) else {
            return CheatSheetPalette.blue.rawValue
        }

        return stripped.uppercased()
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
        let scanner = Scanner(string: CheatSheetPalette.normalizedHex(hex))
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

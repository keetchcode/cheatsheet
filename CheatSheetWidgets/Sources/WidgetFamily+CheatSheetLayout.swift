import SwiftUI
import WidgetKit

extension WidgetFamily {
    var contentPadding: CGFloat {
        switch self {
        case .systemSmall: 16
        case .systemMedium: 18
        default: 20
        }
    }

    var lineLimit: Int {
        switch self {
        case .systemSmall: 4
        case .systemMedium: 5
        default: 9
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .systemSmall: 6
        default: 8
        }
    }

    var verticalSpacing: CGFloat {
        switch self {
        case .systemSmall: 10
        default: 14
        }
    }

    func titleFont(for fontStyle: CheatSheetFontStyle) -> Font {
        switch self {
        case .systemSmall: .system(.headline, design: fontStyle.design).weight(.semibold)
        default: .system(.title3, design: fontStyle.design).weight(.semibold)
        }
    }
}

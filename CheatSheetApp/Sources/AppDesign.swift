import SwiftUI

enum AppDesign {
    static let windowPadding: CGFloat = 24
    static let panelPadding: CGFloat = 16
    static let panelSpacing: CGFloat = 16
    static let editorCornerRadius: CGFloat = 20
    static let editorSectionSpacing: CGFloat = 18
    static let editorTextPadding: CGFloat = 18
    static let previewCornerRadius: CGFloat = 24
    static let controlCornerRadius: CGFloat = 14
    static let minimumHitSize: CGFloat = 44
    static let windowMinimumWidth: CGFloat = 640
    static let windowMinimumHeight: CGFloat = 480
    static let editorMinimumWidth: CGFloat = 320
    static var contentPadding: CGFloat {
        #if os(iOS)
        compactContentPadding
        #else
        windowPadding
        #endif
    }

    static var compactContentPadding: CGFloat {
        16
    }

    static var editorMinimumWidthForCurrentPlatform: CGFloat? {
        #if os(iOS)
        nil
        #else
        editorMinimumWidth
        #endif
    }
}

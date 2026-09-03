import SwiftUI
import UIKit

/// Design tokens — 完全对齐 `qtunnel/design-system/tokens/*.md`
/// 详见 spec 01-architecture §9 与 design-system/MASTER.md
enum DS {

    // MARK: Color

    enum Color {
        // Background
        static let bgGrouped = SwiftUI.Color(UIColor.systemGroupedBackground)
        static let bgSecondary = SwiftUI.Color(UIColor.secondarySystemGroupedBackground)
        static let bgTertiary = SwiftUI.Color(UIColor.tertiarySystemGroupedBackground)

        // Label
        static let labelPrimary = SwiftUI.Color(UIColor.label)
        static let labelSecondary = SwiftUI.Color(UIColor.secondaryLabel)
        static let labelTertiary = SwiftUI.Color(UIColor.tertiaryLabel)

        // Accent
        static let accent = SwiftUI.Color(UIColor.systemBlue)

        // Separator
        static let separator = SwiftUI.Color(UIColor.separator)
        static let separatorOpaque = SwiftUI.Color(UIColor.opaqueSeparator)

        // Status
        static let statusUp = SwiftUI.Color(UIColor.systemGreen)
        static let statusDown = SwiftUI.Color(UIColor.systemRed)
        static let statusUnknown = SwiftUI.Color(UIColor.systemGray)
    }

    // MARK: Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    // MARK: Radius

    enum Radius {
        static let button: CGFloat = 8
        static let card: CGFloat = 12
        static let thumb: CGFloat = 8
    }

    // MARK: Typography

    enum Font {
        static let largeTitle = SwiftUI.Font.largeTitle
        static let title = SwiftUI.Font.title
        static let title2 = SwiftUI.Font.title2
        static let title3 = SwiftUI.Font.title3
        static let headline = SwiftUI.Font.headline
        static let body = SwiftUI.Font.body
        static let callout = SwiftUI.Font.callout
        static let subhead = SwiftUI.Font.subheadline
        static let footnote = SwiftUI.Font.footnote
        static let caption1 = SwiftUI.Font.caption
        static let caption2 = SwiftUI.Font.caption2
        static let mono = SwiftUI.Font.system(.body, design: .monospaced)
    }
}

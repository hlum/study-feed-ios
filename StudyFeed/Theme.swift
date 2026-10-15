import SwiftUI

/// Dark only, one accent. Mirrors the "Design tokens" board.
enum Theme {
    static let bg = Color(hex: 0x0C0C0E)
    static let fill = Color(hex: 0x18181B)
    static let sep = Color(hex: 0x26262A)
    static let ink = Color(hex: 0xEDEDEF)
    static let muted = Color(hex: 0x9C9CA4)
    static let accent = Color(hex: 0xF5C99B)
    static let onAccent = Color(hex: 0x1A120A)
    static let wrong = Color(hex: 0xFF8A80)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Font {
    static func mono(_ style: Font.TextStyle = .footnote) -> Font {
        .system(style, design: .monospaced)
    }
}

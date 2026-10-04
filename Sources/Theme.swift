import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

struct Theme {
    var background: Color
    var text: Color
    var emptyBorder: Color
    var typedBorder: Color
    var correct: Color
    var present: Color
    var absent: Color
    var key: Color
    var keyText: Color
    var tileText: Color = .white

    func color(for e: Eval) -> Color {
        switch e {
        case .correct: return correct
        case .present: return present
        case .absent: return absent
        }
    }

    static func make(dark: Bool, highContrast: Bool) -> Theme {
        var t: Theme
        if dark {
            t = Theme(background: Color(hex: 0x000000), text: Color(hex: 0xF8F8F8), emptyBorder: Color(hex: 0x3A3A3C), typedBorder: Color(hex: 0x565758),
                      correct: Color(hex: 0x538D4E), present: Color(hex: 0xB59F3B), absent: Color(hex: 0x3A3A3C), key: Color(hex: 0x818384), keyText: .white)
        } else {
            t = Theme(background: Color(hex: 0xFFFFFF), text: Color(hex: 0x000000), emptyBorder: Color(hex: 0xD3D6DA), typedBorder: Color(hex: 0x878A8C),
                      correct: Color(hex: 0x6AAA64), present: Color(hex: 0xC9B458), absent: Color(hex: 0x787C7E), key: Color(hex: 0xD3D6DA), keyText: Color(hex: 0x1A1A1B))
        }
        if highContrast {
            t.correct = Color(hex: 0xF5793A)      // orange
            t.present = Color(hex: 0x85C0F9)      // light blue
            if !dark { t.present = Color(hex: 0x5BA7EC) }
        }
        return t
    }
}

private struct ThemeKey: EnvironmentKey { static let defaultValue = Theme.make(dark: false, highContrast: false) }
extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

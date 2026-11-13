import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

enum Theme {
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }

    static let uiBackground = dynamic(0xF4F7F6, 0x101614)
    static let bg = Color(uiBackground)
    static let surface = Color(dynamic(0xFFFFFF, 0x18201E))
    static let surface2 = Color(dynamic(0xEBF0EE, 0x202B28))
    static let fg = Color(dynamic(0x1B2522, 0xE6EEEA))
    static let muted = Color(dynamic(0x65736E, 0x93A39D))
    static let line = Color(dynamic(0xDFE6E3, 0x2A3633))

    static let green = Color(dynamic(0x2E9E6B, 0x3DBB82))
    static let orange = Color(dynamic(0xEE8427, 0xF59A45))
    static let blue = Color(dynamic(0x2F78D4, 0x4C8FE6))

    static let radius: CGFloat = 16
}

extension SubjectColor {
    var main: Color {
        switch self {
        case .green: return Theme.green
        case .orange: return Theme.orange
        case .blue: return Theme.blue
        }
    }

    var soft: Color {
        switch self {
        case .green: return Color(Theme.dynamic(0xE2F3EA, 0x16362A))
        case .orange: return Color(Theme.dynamic(0xFDEDDD, 0x3A2614))
        case .blue: return Color(Theme.dynamic(0xE1ECFA, 0x162A45))
        }
    }

    var ink: Color {
        switch self {
        case .green: return Color(Theme.dynamic(0x1D6B48, 0x86DDB3))
        case .orange: return Color(Theme.dynamic(0x9C4E0C, 0xFFBC7D))
        case .blue: return Color(Theme.dynamic(0x1C5299, 0x94BFF6))
        }
    }
}

extension View {
    func card(_ fill: Color = Theme.surface) -> some View {
        background(fill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

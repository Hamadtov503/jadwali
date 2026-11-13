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

    static let uiBackground = dynamic(0xE6F4EC, 0x0E1A15)
    static let bg = Color(uiBackground)
    static let surface = Color(dynamic(0xFFFFFF, 0x16241E))
    static let surface2 = Color(dynamic(0xD5EBDE, 0x1E3029))
    static let fg = Color(dynamic(0x1B2522, 0xE6EEEA))
    static let muted = Color(dynamic(0x5E7068, 0x93A39D))
    static let line = Color(dynamic(0xCFE3D7, 0x2A3B34))

    static let green = Color(dynamic(0x2E9E6B, 0x3DBB82))
    static let orange = Color(dynamic(0xEE8427, 0xF59A45))
    static let blue = Color(dynamic(0x2F78D4, 0x4C8FE6))
    static let deepGreen = Color(UIColor(hex: 0x165C3E))

    static let radius: CGFloat = 16
}

extension SubjectColor {
    var main: Color {
        switch self {
        case .green: return Theme.green
        case .orange: return Theme.orange
        case .blue: return Theme.blue
        case .purple: return Color(Theme.dynamic(0x8A5CD1, 0xA07DE6))
        case .pink: return Color(Theme.dynamic(0xD4508A, 0xE874A7))
        case .teal: return Color(Theme.dynamic(0x1F9AA8, 0x3BB9C7))
        case .red: return Color(Theme.dynamic(0xD9534F, 0xEB6E6A))
        case .yellow: return Color(Theme.dynamic(0xC9A227, 0xDDBA45))
        }
    }

    var soft: Color {
        switch self {
        case .green: return Color(Theme.dynamic(0xE2F3EA, 0x16362A))
        case .orange: return Color(Theme.dynamic(0xFDEDDD, 0x3A2614))
        case .blue: return Color(Theme.dynamic(0xE1ECFA, 0x162A45))
        case .purple: return Color(Theme.dynamic(0xEEE6FA, 0x2A1F42))
        case .pink: return Color(Theme.dynamic(0xFBE4EF, 0x3C1A2B))
        case .teal: return Color(Theme.dynamic(0xDDF2F4, 0x123538))
        case .red: return Color(Theme.dynamic(0xFBE3E2, 0x3D1A19))
        case .yellow: return Color(Theme.dynamic(0xF8F0D6, 0x362D12))
        }
    }

    var ink: Color {
        switch self {
        case .green: return Color(Theme.dynamic(0x1D6B48, 0x86DDB3))
        case .orange: return Color(Theme.dynamic(0x9C4E0C, 0xFFBC7D))
        case .blue: return Color(Theme.dynamic(0x1C5299, 0x94BFF6))
        case .purple: return Color(Theme.dynamic(0x5B35A0, 0xC7AEF5))
        case .pink: return Color(Theme.dynamic(0x9A2D5E, 0xF5A8CB))
        case .teal: return Color(Theme.dynamic(0x136872, 0x8ADCE5))
        case .red: return Color(Theme.dynamic(0x9E2F2B, 0xF5A3A0))
        case .yellow: return Color(Theme.dynamic(0x7A6110, 0xEBD27A))
        }
    }
}

extension View {
    /// يجعل خلفية النماذج (Form) مثل خلفية التطبيق.
    @ViewBuilder
    func appFormBackground() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
                .background(Theme.bg.ignoresSafeArea())
        } else {
            self.background(Theme.bg.ignoresSafeArea())
        }
    }

    func card(_ fill: Color = Theme.surface) -> some View {
        background(fill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

/// اختيار لون من الألوان المتاحة.
struct ColorGrid: View {
    @Binding var selection: SubjectColor

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(SubjectColor.allCases) { c in
                let on = selection == c
                Button { selection = c } label: {
                    ZStack {
                        Circle().fill(c.main)
                        if on {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 34, height: 34)
                    .padding(3)
                    .overlay(Circle().stroke(on ? c.main : Color.clear, lineWidth: 2))
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(c.title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
    }
}

/// شريحة اختيار بسيطة.
struct Chip: View {
    let title: String
    var color: SubjectColor? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let c = color {
                    Circle().fill(c.main).frame(width: 10, height: 10)
                }
                Text(title)
                    .font(.subheadline.weight(selected ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(selected ? (color?.ink ?? .white) : Theme.fg)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? (color?.soft ?? Theme.green) : Theme.surface2.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? (color?.main ?? Theme.green) : Color.clear, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

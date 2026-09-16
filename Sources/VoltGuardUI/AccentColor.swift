import SwiftUI

enum AccentColor {
    static let presets: [(name: String, hex: String)] = [
        ("Green", "#5CE65C"),
        ("Blue", "#3B82F6"),
        ("Purple", "#A855F7"),
        ("Orange", "#F97316"),
        ("Red", "#EF4444"),
    ]

    static func color(fromHex hex: String?) -> Color? {
        guard var value = hex?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

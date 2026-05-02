import SwiftUI

enum Theme {
    static let primary = Color(red: 0xE8 / 255, green: 0x9B / 255, blue: 0x2C / 255)
    static let primaryDeep = Color(red: 0xB2 / 255, green: 0x6A / 255, blue: 0x14 / 255)
    static let warmDark = Color(red: 0x1A / 255, green: 0x16 / 255, blue: 0x12 / 255)
    static let warmLight = Color(red: 0xFA / 255, green: 0xF7 / 255, blue: 0xF2 / 255)
    static let success = Color(red: 0x16 / 255, green: 0xA3 / 255, blue: 0x4A / 255)
    static let improve = Color(red: 0xEA / 255, green: 0x58 / 255, blue: 0x0C / 255)

    static func categoryColor(_ category: String) -> Color {
        switch category {
        case "Leadership":
            return Color(red: 0x3B / 255, green: 0x6E / 255, blue: 0xE9 / 255)
        case "Business":
            return Color(red: 0x0F / 255, green: 0x76 / 255, blue: 0x6E / 255)
        case "Behavioral":
            return Color(red: 0x16 / 255, green: 0xA3 / 255, blue: 0x4A / 255)
        case "Personal Growth":
            return Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255)
        case "Big Picture":
            return Color(red: 0x7C / 255, green: 0x3A / 255, blue: 0xED / 255)
        case "Education":
            return Color(red: 0x4F / 255, green: 0x46 / 255, blue: 0xE5 / 255)
        default:
            return primary
        }
    }
}

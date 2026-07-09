import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    static let amoledBackground = Color(hex: "000000")
    static let amoledSurface = Color(hex: "111111")

    static let dynamicPrimary: Color = {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(Color(hex: "90CAF9")) : UIColor(Color(hex: "1565C0"))
        }.mapToColor()
    }()

    static let dynamicSecondary: Color = {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(Color(hex: "CE93D8")) : UIColor(Color(hex: "7B1FA2"))
        }.mapToColor()
    }()

    static let dynamicSurface: Color = {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(Color(hex: "1E1E1E")) : UIColor(Color(hex: "FFFFFF"))
        }.mapToColor()
    }()

    static let dynamicBackground: Color = {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(Color(hex: "121212")) : UIColor(Color(hex: "F5F5F5"))
        }.mapToColor()
    }()

    static let dynamicCard: Color = {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(Color(hex: "1E1E1E")) : UIColor(Color(hex: "FFFFFF"))
        }.mapToColor()
    }()

    static let dynamicText: Color = {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(Color(hex: "E0E0E0")) : UIColor(Color(hex: "212121"))
        }.mapToColor()
    }()

    static let dynamicSubtext: Color = {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(Color(hex: "9E9E9E")) : UIColor(Color(hex: "757575"))
        }.mapToColor()
    }()

    static func forFileExtension(_ ext: String) -> Color {
        switch ext.lowercased() {
        case "mp4", "mkv", "avi", "mov", "wmv", "flv", "m4v", "webm":
            return Color(hex: "E53935")
        case "mp3", "flac", "wav", "aac", "ogg", "wma", "m4a":
            return Color(hex: "FB8C00")
        case "jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "heic":
            return Color(hex: "43A047")
        case "pdf", "doc", "docx", "xls", "xlsx", "txt", "rtf", "csv":
            return Color(hex: "1E88E5")
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso":
            return Color(hex: "8E24AA")
        case "apk", "ipa", "exe", "dmg", "deb", "rpm":
            return Color(hex: "00ACC1")
        default:
            return Color(hex: "78909C")
        }
    }
}

extension UIColor {
    func mapToColor() -> Color {
        Color(self)
    }
}

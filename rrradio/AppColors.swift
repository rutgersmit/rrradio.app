import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct AppColors {
    // MARK: - Backgrounds
    static let appBackground = Color("AppBackground")
    static let cardBackground = Color("CardBackground")
    static let playerBackground = Color("PlayerBackground")

    // MARK: - Text
    static let primaryText = Color("PrimaryText")
    static let secondaryText = Color("SecondaryText")

    // MARK: - Accent
    static let accent = Color("AccentColor")

    // MARK: - State
    static let nowPlayingGlow = Color("NowPlayingGlow")
    static let errorColor = Color.red
}

// Fallback computed colors when asset catalog is unavailable
extension Color {
    static var rrBackground: Color {
        Color(light: Color(red: 0.95, green: 0.95, blue: 0.97),
              dark: Color(red: 0.102, green: 0.102, blue: 0.180))
    }
    static var rrCard: Color {
        Color(light: Color(red: 1, green: 1, blue: 1),
              dark: Color(red: 0.15, green: 0.15, blue: 0.25))
    }
    static var rrPlayer: Color {
        Color(light: Color(red: 0.92, green: 0.92, blue: 0.96),
              dark: Color(red: 0.08, green: 0.08, blue: 0.15))
    }
    static var rrPrimaryText: Color {
        Color(light: .black, dark: .white)
    }
    static var rrSecondaryText: Color {
        Color(light: Color(white: 0.4), dark: Color(white: 0.6))
    }
    static var rrAccent: Color {
        Color(red: 0.47, green: 0.33, blue: 0.93)
    }
    static var rrGlow: Color {
        Color(red: 0.47, green: 0.33, blue: 0.93).opacity(0.6)
    }

    init(light: Color, dark: Color) {
        #if os(macOS)
        self.init(NSColor(name: nil, dynamicProvider: { appearance in
            switch appearance.name {
            case .aqua, .vibrantLight, .accessibilityHighContrastAqua, .accessibilityHighContrastVibrantLight:
                return NSColor(light)
            default:
                return NSColor(dark)
            }
        }))
        #else
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
        #endif
    }
}

// Cross-platform helper: create a SwiftUI Image from raw Data
extension Image {
    init?(data: Data) {
        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        self.init(nsImage: image)
        #else
        guard let image = UIImage(data: data) else { return nil }
        self.init(uiImage: image)
        #endif
    }
}

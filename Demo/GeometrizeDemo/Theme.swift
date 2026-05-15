import SwiftUI

/// Single source of truth for colors, type, and motion durations.
/// Keep this small and disciplined — every additional token is a future place
/// for things to drift apart visually.
enum Theme {
    // MARK: Surface
    static let canvas = Color(red: 0.98, green: 0.96, blue: 0.92)             // warm off-white
    static let surface = Color.white
    static let surfaceMuted = Color(red: 0.96, green: 0.94, blue: 0.91)

    // MARK: Ink
    static let ink = Color(red: 0.12, green: 0.11, blue: 0.13)                // near-black
    static let inkMuted = Color(red: 0.42, green: 0.40, blue: 0.44)
    static let inkSubtle = Color(red: 0.70, green: 0.68, blue: 0.72)

    // MARK: Accent (used sparingly — primary CTA + beam)
    static let accent = Color(red: 0.93, green: 0.43, blue: 0.27)             // terracotta

    // MARK: Beam palette (warm pastels, matches the hero)
    static let beamColors: [Color] = [
        Color(red: 0.93, green: 0.43, blue: 0.27),
        Color(red: 0.96, green: 0.78, blue: 0.41),
        Color(red: 0.78, green: 0.69, blue: 0.94),
        Color(red: 0.65, green: 0.82, blue: 0.66)
    ]

    // MARK: Type
    static let serif = "New York"                                              // SF Pro Serif alt; New York ships with iOS
    static func title(_ size: CGFloat = 30) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular)
    }

    // MARK: Motion
    static let smoothSpring: Animation = .spring(duration: 0.45, bounce: 0.05)
    static let crossfade: Animation = .easeInOut(duration: 0.35)
}

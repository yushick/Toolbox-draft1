import SwiftUI

/// Centralized, semantic color system for Toolbox.
/// Add matching color sets named exactly as below to Assets.xcassets
/// (each with a Light and Dark appearance) so these resolve correctly
/// in both modes. A safe fallback keeps the app compiling and looking
/// reasonable even before the assets are created.
enum AppColors {

    // MARK: - Surfaces
    static let background = resolved(light: .init(red: 0.97, green: 0.97, blue: 0.98, alpha: 1),
                                      dark: .init(red: 0.06, green: 0.06, blue: 0.07, alpha: 1))

    static let card = resolved(light: .white,
                                dark: .init(red: 0.11, green: 0.11, blue: 0.13, alpha: 1))

    static let secondaryCard = resolved(light: .init(red: 0.93, green: 0.93, blue: 0.95, alpha: 1),
                                         dark: .init(red: 0.16, green: 0.16, blue: 0.18, alpha: 1))

    // MARK: - Text
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let tertiary = Color(.tertiaryLabel)

    // MARK: - Brand
    /// Kept intentionally muted — a premium utility app, not a toy.
    static let accent = resolved(light: .init(red: 0.20, green: 0.45, blue: 0.98, alpha: 1),
                                  dark: .init(red: 0.35, green: 0.58, blue: 1.0, alpha: 1))

    static var accentSoft: Color { accent.opacity(0.12) }

    // MARK: - Status
    static let success = Color(red: 0.20, green: 0.72, blue: 0.44)
    static let destructive = Color(red: 0.93, green: 0.28, blue: 0.28)
    static let warning = Color(red: 0.95, green: 0.65, blue: 0.15)

    // MARK: - Strokes
    static let separator = Color(.separator)
    static var cardStroke: Color { Color.primary.opacity(0.06) }

    private static func resolved(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
}

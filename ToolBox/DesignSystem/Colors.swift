import SwiftUI

/// Centralized, semantic colour system for Toolbox.
///
/// Dark-first: near-black surfaces, one lime accent, off-white text.
/// A Light variant of every token is kept so the Appearance setting
/// (System / Light / Dark) keeps working.
///
/// Rule of thumb: text or icons that sit ON the accent use `ink`
/// (never white), and text on the saturated blocks uses `onBlock`.
enum AppColors {

    // MARK: - Surfaces
    static let background = resolved(light: rgb(0.955, 0.955, 0.945),
                                     dark: rgb(0.02, 0.02, 0.025))

    /// Elevated container, one step above the background.
    static let card = resolved(light: rgb(1, 1, 1),
                               dark: rgb(0.095, 0.095, 0.11))

    /// Inputs, chips, secondary buttons, icon tiles.
    static let secondaryCard = resolved(light: rgb(0.91, 0.91, 0.90),
                                        dark: rgb(0.155, 0.155, 0.175))

    // MARK: - Text
    static let primary = resolved(light: rgb(0.05, 0.05, 0.06),
                                  dark: rgb(0.95, 0.95, 0.93))
    static let secondary = resolved(light: rgb(0.40, 0.42, 0.47),
                                    dark: rgb(0.56, 0.58, 0.64))
    static let tertiary = resolved(light: rgb(0.58, 0.60, 0.65),
                                   dark: rgb(0.40, 0.42, 0.48))

    // MARK: - Accent
    /// Lime in dark mode; a deeper green in light mode so it stays legible
    /// on white. Always pair fills of this colour with `ink`.
    /// Follows the user's theme colour (Settings → Theme Color).
    static var accent: Color {
        let theme = AppTheme.current
        return resolved(light: theme.light.ui, dark: theme.dark.ui)
    }

    static var accentSoft: Color { accent.opacity(0.14) }

    /// Text / icons placed on top of the accent colour.
    static var ink: Color {
        let theme = AppTheme.current
        return resolved(light: theme.inkOnLight.ui, dark: theme.inkOnDark.ui)
    }

    /// The theme colour as a big feature block: the bright version in both
    /// modes, with matching text colour.
    static var accentBlock: Color { AppTheme.current.dark.color }
    static var onAccentBlock: Color { AppTheme.current.inkOnDark.color }

    // MARK: - Saturated blocks (same in both modes)
    /// Large feature surfaces, used sparingly: one block colour per category.
    static let blockBlue = Color(red: 0.19, green: 0.13, blue: 0.98)
    static let blockOrange = Color(red: 0.92, green: 0.29, blue: 0.16)
    /// Text on blockBlue / blockOrange.
    static let onBlock = Color.white

    // MARK: - Status
    static let success = Color(red: 0.20, green: 0.78, blue: 0.46)
    static let destructive = Color(red: 0.95, green: 0.30, blue: 0.28)
    static let warning = Color(red: 0.98, green: 0.68, blue: 0.15)

    // MARK: - Strokes
    static let separator = resolved(light: UIColor.black.withAlphaComponent(0.08),
                                    dark: UIColor.white.withAlphaComponent(0.08))
    static let cardStroke = resolved(light: UIColor.black.withAlphaComponent(0.06),
                                     dark: UIColor.white.withAlphaComponent(0.07))

    // MARK: - Helpers
    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
        UIColor(red: r, green: g, blue: b, alpha: 1)
    }

    private static func resolved(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
}

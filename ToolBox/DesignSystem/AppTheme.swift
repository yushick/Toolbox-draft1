import SwiftUI

/// The user's chosen theme colour. It drives the accent used for buttons,
/// selections and progress, the big feature blocks, and the Home gradient.
///
/// Each theme defines a Dark and a Light version of its colour, plus the
/// ink (text/icon colour) that stays readable on top of each one.
enum AppTheme: String, CaseIterable, Identifiable {
    case neonGreen, electricBlue, sunsetOrange, hotPink, violet, aqua, racingRed

    static let storageKey = "themeColor"
    static let `default`: AppTheme = .neonGreen

    /// Read straight from UserDefaults so non-view code (and AppColors)
    /// always sees the current choice.
    static var current: AppTheme {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppTheme.init(rawValue:)) ?? .default
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neonGreen: return "Neon Green"
        case .electricBlue: return "Electric Blue"
        case .sunsetOrange: return "Sunset Orange"
        case .hotPink: return "Hot Pink"
        case .violet: return "Violet"
        case .aqua: return "Aqua"
        case .racingRed: return "Racing Red"
        }
    }

    struct RGB {
        let r: CGFloat, g: CGFloat, b: CGFloat
        init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) { self.r = r; self.g = g; self.b = b }
        var ui: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
        var color: Color { Color(red: r, green: g, blue: b) }
    }

    private static let darkInk = RGB(0.04, 0.05, 0.02)
    private static let whiteInk = RGB(1, 1, 1)

    /// Accent on dark surfaces (also used for big feature blocks in both modes).
    var dark: RGB {
        switch self {
        case .neonGreen: return RGB(0.78, 1.00, 0.30)
        case .electricBlue: return RGB(0.25, 0.40, 1.00)
        case .sunsetOrange: return RGB(1.00, 0.50, 0.15)
        case .hotPink: return RGB(1.00, 0.30, 0.65)
        case .violet: return RGB(0.65, 0.45, 1.00)
        case .aqua: return RGB(0.20, 0.90, 0.95)
        case .racingRed: return RGB(1.00, 0.30, 0.30)
        }
    }

    /// Accent on light surfaces: deeper, so it stays legible on white.
    var light: RGB {
        switch self {
        case .neonGreen: return RGB(0.33, 0.60, 0.00)
        case .electricBlue: return RGB(0.15, 0.25, 0.95)
        case .sunsetOrange: return RGB(0.90, 0.38, 0.05)
        case .hotPink: return RGB(0.85, 0.10, 0.50)
        case .violet: return RGB(0.45, 0.20, 0.90)
        case .aqua: return RGB(0.00, 0.55, 0.65)
        case .racingRed: return RGB(0.85, 0.12, 0.15)
        }
    }

    /// Text/icons on top of `dark`.
    var inkOnDark: RGB {
        self == .electricBlue ? Self.whiteInk : Self.darkInk
    }

    /// Text/icons on top of `light`.
    var inkOnLight: RGB {
        switch self {
        case .neonGreen, .sunsetOrange, .aqua: return Self.darkInk
        default: return Self.whiteInk
        }
    }
}

/// Home's background: near-black (or off-white) with a soft wash of the
/// theme colour fading down from the top, plus a glow in the corner.
struct HomeGradientBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let isDark = scheme == .dark
        ZStack(alignment: .top) {
            AppColors.background

            LinearGradient(
                stops: [
                    .init(color: AppColors.accent.opacity(isDark ? 0.30 : 0.22), location: 0),
                    .init(color: AppColors.accent.opacity(isDark ? 0.10 : 0.07), location: 0.32),
                    .init(color: AppColors.accent.opacity(0), location: 0.65)
                ],
                startPoint: .top, endPoint: .bottom)

            RadialGradient(
                colors: [AppColors.accent.opacity(isDark ? 0.30 : 0.18), AppColors.accent.opacity(0)],
                center: .topTrailing, startRadius: 0, endRadius: 360)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

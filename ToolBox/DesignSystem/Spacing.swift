import SwiftUI

/// Centralized spacing & radius scale so layout stays visually
/// consistent across every screen.
enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum AppRadius {
    static let small: CGFloat = 10
    static let medium: CGFloat = 16
    static let large: CGFloat = 22
}

enum AppShadow {
    /// Deliberately soft — this app should never look "flat design meets drop shadow demo".
    static func card() -> some ViewModifier { CardShadow() }
}

private struct CardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

extension View {
    func cardShadow() -> some View { modifier(AppShadow.card()) }
}

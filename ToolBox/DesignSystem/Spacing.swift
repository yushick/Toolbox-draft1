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

/// Generous radii: soft, pill-like shapes are part of the identity.
enum AppRadius {
    static let small: CGFloat = 14
    static let medium: CGFloat = 22
    static let large: CGFloat = 32
}

enum AppShadow {
    /// Dark mode relies on surface contrast instead of shadows; light mode
    /// gets a barely-there lift.
    static func card() -> some ViewModifier { CardShadow() }
}

private struct CardShadow: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.shadow(color: Color.black.opacity(scheme == .dark ? 0 : 0.05),
                       radius: 12, x: 0, y: 4)
    }
}

extension View {
    func cardShadow() -> some View { modifier(AppShadow.card()) }
}

/// Subtle press feedback for tappable cards and rows.
/// Use instead of `.buttonStyle(.plain)` on custom card buttons.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

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

/// Pure OLED black canvas with a subtle top 38% teal-to-indigo ambient glow
/// shared across Home, Tools, and Files.
struct AmbientCanvasBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height * 0.38
            ZStack(alignment: .top) {
                Color.black

                RadialGradient(
                    colors: [
                        Color(red: 0.0, green: 0.63, blue: 0.61).opacity(0.40),
                        Color(red: 0.12, green: 0.13, blue: 1.0).opacity(0.22),
                        Color.black
                    ],
                    center: .top,
                    startRadius: 10,
                    endRadius: height
                )
                .frame(height: height)
                .drawingGroup()
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .ignoresSafeArea()
    }
}

/// Reusable iOS 26 Liquid Glass filter pill with `.ultraThinMaterial` fallback.
struct LiquidGlassFilterChip: View {
    let title: String
    let isSelected: Bool
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.75))
            .padding(.horizontal, 14)
            .frame(height: 34)
            .modifier(FilterChipGlassModifier(isSelected: isSelected))
        }
        .buttonStyle(.plain)
    }
}

private struct FilterChipGlassModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    isSelected ? .regular.tint(AppColors.accent).interactive() : .regular.interactive(),
                    in: .capsule
                )
        } else {
            content
                .background(
                    Capsule().fill(isSelected ? AppColors.accent.opacity(0.85) : Color.white.opacity(0.08))
                )
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(isSelected ? 0.25 : 0.12), lineWidth: 1)
                }
        }
    }
}

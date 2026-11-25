import SwiftUI

extension View {
    /// Liquid Glass surface for feature cards.
    ///
    /// On iOS 26+ (built with Xcode 26) this is the real system Liquid Glass,
    /// tinted with the theme colour and reacting to touch. On iOS 18–25 it falls
    /// back to a frosted material with a glass-like edge highlight, so the app
    /// still looks right everywhere.
    func liquidGlass(cornerRadius: CGFloat,
                     tint: Color? = nil,
                     interactive: Bool = true) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }
}

private struct LiquidGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private var glass: Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
    #endif

    /// Frosted material + tint + a bright edge that fades, like light
    /// catching the rim of a glass pane.
    private func fallback(_ content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    if let tint { shape.fill(tint) }
                    shape.fill(
                        LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0)],
                                       startPoint: .topLeading, endPoint: .center))
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.40),
                                            Color.white.opacity(0.06),
                                            Color.white.opacity(0.18)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1)
            }
            .clipShape(shape)
    }
}

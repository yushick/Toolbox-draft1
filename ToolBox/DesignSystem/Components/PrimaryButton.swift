import SwiftUI

/// Full-width capsule button. Lime fill with dark ink text.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
        }
        .buttonStyle(ToolboxButtonStyle(kind: .primary))
    }
}

/// Full-width capsule button on a raised surface.
struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
        }
        .buttonStyle(ToolboxButtonStyle(kind: .secondary))
    }
}

/// The shared look for the two buttons above. Also usable directly:
/// `Button("Go") { }.buttonStyle(ToolboxButtonStyle(kind: .primary))`.
struct ToolboxButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        StyledButton(kind: kind, configuration: configuration)
    }

    private struct StyledButton: View {
        let kind: Kind
        let configuration: ButtonStyle.Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(AppFont.button())
                .foregroundStyle(kind == .primary ? AppColors.ink : AppColors.primary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
                .background(kind == .primary ? AppColors.accent : AppColors.secondaryCard, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(kind == .primary ? Color.clear : AppColors.cardStroke, lineWidth: 1)
                )
                .opacity(isEnabled ? 1 : 0.4)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .contentShape(Capsule())
        }
    }
}

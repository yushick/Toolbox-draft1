import SwiftUI

/// Home's import control. A floating "+" button: tap it and it turns into
/// "×" while Photos / Files slide out beside it. When a file is dragged
/// over Home, the row becomes a dashed "Drop to import" target.
///
/// The row is a fixed height in every state, so nothing below it ever
/// shifts or jumps while it animates.
struct ImportDropZone: View {
    var isTargeted: Bool = false
    var isBusy: Bool = false
    var onPhotos: () -> Void
    var onFiles: () -> Void

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let rowHeight: CGFloat = 60

    private var spring: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 0.78)
    }

    var body: some View {
        ZStack {
            if isTargeted {
                dropTarget
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                controls
                    .transition(.opacity)
            }
        }
        .frame(height: rowHeight)
        .animation(spring, value: isTargeted)
        .onChange(of: isTargeted) { _, targeted in
            if targeted { isExpanded = false }
        }
    }

    // MARK: - Normal state

    private var controls: some View {
        HStack(spacing: AppSpacing.md) {
            plusButton

            ZStack(alignment: .leading) {
                if isExpanded {
                    HStack(spacing: AppSpacing.sm) {
                        choice("Photos", symbol: "photo.on.rectangle") { pick(onPhotos) }
                        choice("Files", symbol: "folder") { pick(onFiles) }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading)
                            .combined(with: .scale(scale: 0.85, anchor: .leading))
                            .combined(with: .opacity),
                        removal: .opacity))
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import a file").appHeadline()
                        Text("PDF or photo — or drop one here").appSecondary()
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var plusButton: some View {
        Button {
            withAnimation(spring) { isExpanded.toggle() }
        } label: {
            ZStack {
                Circle().fill(AppColors.accent)
                if isBusy {
                    ProgressView().tint(AppColors.ink)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                        .rotationEffect(.degrees(isExpanded ? 135 : 0))
                }
            }
            .frame(width: 56, height: 56)
            .shadow(color: AppColors.accent.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(isBusy)
        .accessibilityLabel(isExpanded ? "Close import options" : "Import a file")
        .accessibilityHint("Choose a PDF or photo to see what you can do with it")
    }

    private func choice(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .padding(.horizontal, AppSpacing.lg)
                .frame(minHeight: 44)
                .background(AppColors.card, in: Capsule())
                .overlay(Capsule().strokeBorder(AppColors.accent.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
    }

    private func pick(_ action: @escaping () -> Void) {
        withAnimation(spring) { isExpanded = false }
        action()
    }

    // MARK: - Dragging a file over Home

    private var dropTarget: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "arrow.down.circle.fill")
            Text("Drop to import")
        }
        .font(.system(.headline, weight: .semibold))
        .foregroundStyle(AppColors.accent)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Capsule().fill(AppColors.accent.opacity(0.10)))
        .overlay(
            Capsule().strokeBorder(AppColors.accent,
                                   style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
        )
    }
}

private struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

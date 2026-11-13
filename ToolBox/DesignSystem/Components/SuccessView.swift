import SwiftUI

/// Reusable result screen. Different tools pass different `stat`
/// content (e.g. "18.4 MB → 4.2 MB") but share the same shape, per
/// the product spec's Result component.
///
/// The numbers reveal in order (original, then arrow, then result, then
/// the "Saved…" line). With Reduce Motion or VoiceOver on, everything is
/// simply shown at once.
struct SuccessView: View {
    let title: String
    let message: String
    /// Optional "before → after" style summary, e.g. size saved.
    var statBefore: String? = nil
    var statAfter: String? = nil
    var statCaption: String? = nil

    var onShare: (() -> Void)? = nil
    var onSaveToFiles: (() -> Void)? = nil
    /// Lets tools relabel the save action (e.g. "Save Images").
    var saveTitle: String = "Save to Files"
    var saveIcon: String = "folder"
    /// Optional extra content, e.g. a per-item list for batch results.
    var extraContent: AnyView? = nil
    var onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 nothing · 1 check · 2 original · 3 result · 4 caption
    @State private var step = 0

    private var hasStat: Bool { statAfter != nil }

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer(minLength: AppSpacing.xxl)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.success)
                .scaleEffect(step >= 1 ? 1 : 0.6)
                .opacity(step >= 1 ? 1 : 0)
                .accessibilityHidden(true)

            VStack(spacing: AppSpacing.xs) {
                Text(title).appTitle()
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .appSecondary()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            if hasStat { statBlock }

            if let extraContent {
                extraContent
            }

            Spacer()

            VStack(spacing: AppSpacing.sm) {
                if let onShare {
                    PrimaryButton(title: "Share", systemImage: "square.and.arrow.up", action: onShare)
                }
                if let onSaveToFiles {
                    SecondaryButton(title: saveTitle, systemImage: saveIcon, action: onSaveToFiles)
                }
                Button("Done", action: onDone)
                    .font(.system(.body, weight: .semibold))
                    .frame(minWidth: 44, minHeight: 44)
                    .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.xl)
        .background(AppColors.background)
        .task { await reveal() }
    }

    // MARK: - Stat block

    private var statBlock: some View {
        VStack(spacing: AppSpacing.xs) {
            if let statBefore {
                Text(statBefore)
                    .appSecondary()
                    .strikethrough()
                    .opacity(step >= 2 ? 1 : 0)

                Image(systemName: "arrow.down")
                    .foregroundStyle(AppColors.secondary)
                    .opacity(step >= 3 ? 1 : 0)
            }

            Text(statAfter ?? "")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .scaleEffect(step >= 3 ? 1 : 0.85)
                .opacity(step >= (statBefore == nil ? 2 : 3) ? 1 : 0)

            if let statCaption {
                Text(statCaption)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(AppColors.success)
                    .opacity(step >= 4 ? 1 : 0)
                    .offset(y: step >= 4 ? 0 : 6)
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.secondaryCard, in: RoundedRectangle(cornerRadius: AppRadius.medium))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        if let statBefore, let statAfter { parts.append("From \(statBefore) to \(statAfter)") }
        else if let statAfter { parts.append(statAfter) }
        if let statCaption { parts.append(statCaption) }
        return parts.joined(separator: ". ")
    }

    // MARK: - Reveal

    private func reveal() async {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        if reduceMotion || UIAccessibility.isVoiceOverRunning {
            step = 4
            return
        }
        for next in 1...4 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { step = next }
            try? await Task.sleep(for: .milliseconds(next == 1 ? 350 : 300))
        }
    }
}

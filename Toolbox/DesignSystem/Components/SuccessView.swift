import SwiftUI

/// Reusable result screen. Different tools pass different `stat`
/// content (e.g. "18.4 MB → 4.2 MB") but share the same shape, per
/// the product spec's Result component.
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

    @State private var appeared = false

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer(minLength: AppSpacing.xxl)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.success)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.65), value: appeared)

            VStack(spacing: AppSpacing.xs) {
                Text(title).appTitle()
                Text(message)
                    .appSecondary()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            if let statBefore, let statAfter {
                VStack(spacing: AppSpacing.xs) {
                    Text(statBefore).appSecondary().strikethrough()
                    Image(systemName: "arrow.down")
                        .foregroundStyle(AppColors.secondary)
                    Text(statAfter)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    if let statCaption {
                        Text(statCaption)
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(AppColors.success)
                    }
                }
                .padding(AppSpacing.lg)
                .background(AppColors.secondaryCard, in: RoundedRectangle(cornerRadius: AppRadius.medium))
            }

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
                    .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.xl)
        .background(AppColors.background)
        .onAppear { appeared = true }
    }
}

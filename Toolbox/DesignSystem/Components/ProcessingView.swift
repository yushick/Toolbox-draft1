import SwiftUI

/// One reusable processing component, shared by PDF compression,
/// image compression, OCR, PDF creation and batch resizing — per the
/// product spec, this is intentionally the only progress UI in the app.
struct ProcessingView: View {
    let title: String
    /// 0...1, or nil for an indeterminate spinner (used when progress
    /// can't be estimated, e.g. short OCR passes).
    let progress: Double?
    var detail: String? = nil
    var onCancel: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Text(title).appHeadline()

            if let progress {
                ProgressView(value: progress)
                    .tint(AppColors.accent)
                    .frame(maxWidth: 240)
                Text("\(Int(progress * 100))%")
                    .appSecondary()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: progress)
            } else {
                ProgressView()
                    .tint(AppColors.accent)
                    .controlSize(.large)
            }

            if let detail {
                Text(detail).appCaption()
            }

            if let onCancel {
                Button("Cancel", role: .cancel, action: onCancel)
                    .font(.system(.subheadline, weight: .semibold))
                    .padding(.top, AppSpacing.sm)
            }
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .accessibilityElement(children: .combine)
    }
}

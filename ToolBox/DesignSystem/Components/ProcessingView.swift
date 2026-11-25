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
            Text(title).appSectionTitle()

            if let progress {
                VStack(spacing: AppSpacing.lg) {
                    Text("\(Int(progress * 100))%")
                        .font(AppFont.numeral())
                        .foregroundStyle(AppColors.accent)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: progress)

                    ProgressTrack(value: progress)
                        .frame(maxWidth: 260, minHeight: 8, maxHeight: 8)
                }
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
                    .foregroundStyle(AppColors.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .accessibilityElement(children: .combine)
        .accessibilityValue(progress.map { "\(Int($0 * 100)) percent" } ?? "In progress")
    }
}

/// Slim capsule progress bar in the accent colour.
private struct ProgressTrack: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.secondaryCard)
                Capsule()
                    .fill(AppColors.accent)
                    .frame(width: max(8, proxy.size.width * min(max(value, 0), 1)))
                    .animation(.easeOut(duration: 0.2), value: value)
            }
        }
    }
}

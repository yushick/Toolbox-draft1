import SwiftUI

/// Quiet sign-off at the bottom of Home: hairlines that fade out on both
/// sides of a small spark, the studio name, and the app version.
struct AppFooter: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                hairline(fadingToward: .leading)
                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.accent)
                hairline(fadingToward: .trailing)
            }

            VStack(spacing: 6) {
                Text("CRAFTED BY")
                    .font(.system(.caption2, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(AppColors.tertiary)

                (Text("socara").foregroundStyle(AppColors.primary)
                 + Text("Labs").foregroundStyle(AppColors.accent))
                    .font(AppFont.sectionTitle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.xl)
        .padding(.top, AppSpacing.xl)
        .padding(.bottom, AppSpacing.xxl)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Developed by SocaraLabs. Version \(AppInfo.versionString)")
    }

    private func hairline(fadingToward edge: HorizontalEdge) -> some View {
        Capsule()
            .fill(LinearGradient(
                colors: [AppColors.separator.opacity(edge == .leading ? 0 : 1),
                         AppColors.separator.opacity(edge == .leading ? 1 : 0)],
                startPoint: .leading, endPoint: .trailing))
            .frame(height: 1)
    }
}

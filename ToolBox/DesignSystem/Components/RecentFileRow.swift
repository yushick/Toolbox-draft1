import SwiftUI

struct RecentFileRow: View {
    let icon: String
    let name: String
    let detail: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.accent)
                .frame(width: 34, height: 34)
                .background(AppColors.accentSoft, in: RoundedRectangle(cornerRadius: AppRadius.small))

            VStack(alignment: .leading, spacing: 1) {
                Text(name).appBody().lineLimit(1)
                Text(detail).appCaption()
            }
            Spacer()
            Image(systemName: "chevron.right")
                .appCaption()
        }
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.lg)
        .frame(minHeight: 44)
    }
}

/// Row used on the Files tab — same shape as RecentFileRow, adds size.
struct FileRow: View {
    let icon: String
    let name: String
    let sizeDescription: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppColors.accent)
                .frame(width: 38, height: 38)
                .background(AppColors.accentSoft, in: RoundedRectangle(cornerRadius: AppRadius.small))

            VStack(alignment: .leading, spacing: 1) {
                Text(name).appBody().lineLimit(1)
                Text(sizeDescription).appCaption()
            }
            Spacer()
        }
        .padding(.vertical, AppSpacing.xs)
        .frame(minHeight: 44)
    }
}

import SwiftUI

/// Compact Liquid Glass card used for secondary tools, shown two-up in a grid.
struct ToolCard: View {
    let tool: Tool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Image(systemName: tool.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.ink)
                .frame(width: 40, height: 40)
                .background(AppColors.accent, in: RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(tool.title).appHeadline()
                Text(tool.subtitle).appSecondary()
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .liquidGlass(cornerRadius: AppRadius.medium, tint: AppColors.accent.opacity(0.08))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Large Liquid Glass "hero" card used for the top-priority tools
/// (Scan Document, Compress PDF).
struct LargeToolCard: View {
    let tool: Tool

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(tool.title).appTitle()
                Text(tool.subtitle).appSecondary()
            }
            Spacer(minLength: AppSpacing.md)
            Image(systemName: tool.icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppColors.ink)
                .frame(width: 60, height: 60)
                .background(AppColors.accent, in: RoundedRectangle(cornerRadius: AppRadius.small + 4, style: .continuous))
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .liquidGlass(cornerRadius: AppRadius.large, tint: AppColors.accent.opacity(0.09))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

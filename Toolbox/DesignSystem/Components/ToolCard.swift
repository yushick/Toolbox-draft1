import SwiftUI

/// Compact card used for secondary tools, shown two-up in a grid.
struct ToolCard: View {
    let tool: Tool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Image(systemName: tool.icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(AppColors.accent)
                .frame(width: 40, height: 40)
                .background(AppColors.accentSoft, in: RoundedRectangle(cornerRadius: AppRadius.small))

            VStack(alignment: .leading, spacing: 2) {
                Text(tool.title).appHeadline()
                Text(tool.subtitle).appCaption()
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
        )
        .cardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Large "hero" card used for the top-priority tools (Scan Document,
/// Compress PDF) — visually bigger per the product spec.
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
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(AppColors.accent)
                .frame(width: 56, height: 56)
                .background(AppColors.accentSoft, in: RoundedRectangle(cornerRadius: AppRadius.small))
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
        )
        .cardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

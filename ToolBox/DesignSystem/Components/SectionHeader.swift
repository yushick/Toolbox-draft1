import SwiftUI

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .appSectionTitle()
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(AppColors.secondary)
                    .frame(minHeight: 44)
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }
}

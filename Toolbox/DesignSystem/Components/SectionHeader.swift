import SwiftUI

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(AppColors.secondary)
                .tracking(0.5)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(.footnote, weight: .semibold))
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .accessibilityAddTraits(.isHeader)
    }
}

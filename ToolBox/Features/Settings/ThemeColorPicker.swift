import SwiftUI

/// A row of colour swatches for choosing the app's theme colour.
struct ThemeColorPicker: View {
    @Binding var selection: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Theme Color")
                Spacer()
                Text(selection.title).foregroundStyle(AppColors.secondary)
            }

            HStack(spacing: 0) {
                ForEach(AppTheme.allCases) { theme in
                    swatch(theme)
                    if theme != AppTheme.allCases.last { Spacer(minLength: 0) }
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private func swatch(_ theme: AppTheme) -> some View {
        let isSelected = selection == theme
        return Button {
            guard selection != theme else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            selection = theme
        } label: {
            ZStack {
                Circle()
                    .fill(theme.dark.color)
                    .frame(width: 34, height: 34)
                if isSelected {
                    Circle()
                        .strokeBorder(AppColors.primary, lineWidth: 2)
                        .frame(width: 44, height: 44)
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(theme.inkOnDark.color)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

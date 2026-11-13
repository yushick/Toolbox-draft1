import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search tools..."

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColors.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !text.isEmpty {
                Button {
                    withAnimation(.snappy) { text = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColors.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 44)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
    }
}

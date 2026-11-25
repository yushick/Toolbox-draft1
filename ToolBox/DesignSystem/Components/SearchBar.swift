import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search tools..."
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isFocused ? AppColors.accent : AppColors.secondary)
            TextField("", text: $text,
                      prompt: Text(placeholder).foregroundStyle(AppColors.secondary))
                .focused($isFocused)
                .foregroundStyle(AppColors.primary)
                .tint(AppColors.accent)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !text.isEmpty {
                Button {
                    withAnimation(.snappy) { text = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColors.secondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, AppSpacing.lg)
        .padding(.trailing, text.isEmpty ? AppSpacing.lg : 0)
        .frame(height: 52)
        .background(AppColors.card, in: Capsule())
        .overlay(
            Capsule().strokeBorder(isFocused ? AppColors.accent.opacity(0.8) : AppColors.cardStroke,
                                   lineWidth: isFocused ? 1.5 : 1)
        )
        .animation(.easeOut(duration: 0.15), value: isFocused)
        .contentShape(Capsule())
        .onTapGesture { isFocused = true }
    }
}

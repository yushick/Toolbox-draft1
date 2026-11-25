import SwiftUI

private struct SearchGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search tools..."
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField(placeholder, text: $text)
                    .focused($isFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.search)
                    .onSubmit {
                        isFocused = false
                    }

                if !text.isEmpty {
                    Button("Clear search", systemImage: "xmark.circle.fill") {
                        withAnimation(.snappy) { text = "" }
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .modifier(SearchGlassModifier())

            if isFocused {
                Button("Cancel") {
                    withAnimation(.snappy) {
                        text = ""
                        isFocused = false
                    }
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: isFocused)
    }
}

import SwiftUI

enum OnboardingState {
    static let completedKey = "hasCompletedOnboarding"
}

/// Two short screens shown on first launch. No account, no tutorial.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Page {
        let symbol: String
        let title: String
        let message: String
    }

    private let pages = [
        Page(symbol: "square.grid.2x2",
             title: "Your everyday tools.",
             message: "Scan documents, compress files, resize images and more."),
        Page(symbol: "lock.shield",
             title: "Private by design.",
             message: "Your files are processed locally whenever possible.")
    ]

    private var isLastPage: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index]).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageDots

            PrimaryButton(title: isLastPage ? "Get Started" : "Continue") {
                if isLastPage {
                    onFinish()
                } else if reduceMotion {
                    page += 1
                } else {
                    withAnimation(.snappy) { page += 1 }
                }
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background.ignoresSafeArea())
    }

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            Image(systemName: page.symbol)
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(AppColors.accent)
                .frame(width: 104, height: 104)
                .background(AppColors.accentSoft, in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                .accessibilityHidden(true)

            VStack(spacing: AppSpacing.sm) {
                Text(page.title)
                    .appLargeTitle()
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(page.message)
                    .font(AppFont.body())
                    .foregroundStyle(AppColors.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.xxl)
            Spacer()
        }
    }

    private var pageDots: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? AppColors.accent : AppColors.secondary.opacity(0.3))
                    .frame(width: index == page ? 22 : 8, height: 8)
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(pages.count)")
    }
}

#Preview {
    OnboardingView(onFinish: {})
}

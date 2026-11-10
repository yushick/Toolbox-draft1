import SwiftUI

/// Reusable, Dynamic-Type-aware text styles. Never hardcode fonts
/// elsewhere in the app — extend this file instead.
enum AppFont {
    static func largeTitle() -> Font { .system(.largeTitle, design: .rounded, weight: .bold) }
    static func title() -> Font { .system(.title2, design: .rounded, weight: .semibold) }
    static func headline() -> Font { .system(.headline, design: .default, weight: .semibold) }
    static func body() -> Font { .system(.body, design: .default, weight: .regular) }
    static func secondary() -> Font { .system(.subheadline, design: .default, weight: .regular) }
    static func caption() -> Font { .system(.caption, design: .default, weight: .medium) }
}

extension View {
    func appLargeTitle() -> some View { font(AppFont.largeTitle()).foregroundStyle(AppColors.primary) }
    func appTitle() -> some View { font(AppFont.title()).foregroundStyle(AppColors.primary) }
    func appHeadline() -> some View { font(AppFont.headline()).foregroundStyle(AppColors.primary) }
    func appBody() -> some View { font(AppFont.body()).foregroundStyle(AppColors.primary) }
    func appSecondary() -> some View { font(AppFont.secondary()).foregroundStyle(AppColors.secondary) }
    func appCaption() -> some View { font(AppFont.caption()).foregroundStyle(AppColors.tertiary) }
}

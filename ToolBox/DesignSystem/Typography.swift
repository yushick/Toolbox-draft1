import SwiftUI

/// Reusable, Dynamic-Type-aware text styles. Never hardcode fonts
/// elsewhere in the app — extend this file instead.
///
/// Headings use SF's *expanded* width in heavy weights for a bold,
/// confident voice; body and metadata stay in regular SF Pro for readability.
enum AppFont {
    /// Screen titles ("Toolbox").
    static func largeTitle() -> Font { .system(.largeTitle, design: .default, weight: .heavy).width(.expanded) }
    /// Tool names on cards.
    static func title() -> Font { .system(.title2, design: .default, weight: .bold).width(.expanded) }
    /// Section headings.
    static func sectionTitle() -> Font { .system(.title3, design: .default, weight: .bold).width(.expanded) }
    static func headline() -> Font { .system(.headline, design: .default, weight: .bold) }
    static func body() -> Font { .system(.body, design: .default, weight: .regular) }
    static func secondary() -> Font { .system(.subheadline, design: .default, weight: .regular) }
    static func caption() -> Font { .system(.caption, design: .default, weight: .medium) }
    /// Buttons.
    static func button() -> Font { .system(.body, design: .default, weight: .bold) }
    /// Big stat numbers (percentages, sizes).
    static func numeral() -> Font { .system(.largeTitle, design: .default, weight: .heavy).width(.expanded) }
}

extension View {
    func appLargeTitle() -> some View { font(AppFont.largeTitle()).foregroundStyle(AppColors.primary) }
    func appTitle() -> some View { font(AppFont.title()).foregroundStyle(AppColors.primary) }
    func appSectionTitle() -> some View { font(AppFont.sectionTitle()).foregroundStyle(AppColors.primary) }
    func appHeadline() -> some View { font(AppFont.headline()).foregroundStyle(AppColors.primary) }
    func appBody() -> some View { font(AppFont.body()).foregroundStyle(AppColors.primary) }
    func appSecondary() -> some View { font(AppFont.secondary()).foregroundStyle(AppColors.secondary) }
    func appCaption() -> some View { font(AppFont.caption()).foregroundStyle(AppColors.tertiary) }
}

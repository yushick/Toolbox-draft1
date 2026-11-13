import SwiftUI

/// A titled block of plain-language text, shared by both privacy screens.
private struct PrivacyBlock: View {
    let title: String
    let text: String
    var symbol: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                if let symbol {
                    Image(systemName: symbol)
                        .foregroundStyle(AppColors.accent)
                        .accessibilityHidden(true)
                }
                Text(title).appHeadline()
            }
            .accessibilityAddTraits(.isHeader)
            Text(text).appSecondary()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
        )
    }
}

/// What the app does with your data, in plain language.
struct DataPrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                PrivacyBlock(
                    title: "Your files stay on your iPhone",
                    text: "Toolbox scans, compresses, resizes and reads your documents, images and codes on your device. There's no account, no Toolbox server, and no analytics or tracking in the app.",
                    symbol: "iphone")

                PrivacyBlock(
                    title: "What Toolbox keeps",
                    text: "Files you create are saved in Toolbox's storage on your iPhone. You can see them in the Files tab, or in the Files app under On My iPhone › Toolbox. Toolbox also keeps a short list of recent activity (the tool used and when, never file contents) and your settings.",
                    symbol: "internaldrive")

                PrivacyBlock(
                    title: "Permissions",
                    text: "Camera: only when you open a scanning tool, to scan documents, codes and text. Photos: you choose photos with Apple's picker, so Toolbox only sees the ones you pick. It asks to add photos only if you tap Save Images. Wi-Fi: only if you tap Connect on a scanned Wi-Fi code.",
                    symbol: "hand.raised")

                PrivacyBlock(
                    title: "When something leaves your iPhone",
                    text: "Only when you choose it: sharing a file with the share sheet, opening a scanned link, or tapping Search Web on a barcode (which opens your browser and searches for that number). Nothing opens on its own.",
                    symbol: "arrow.up.right.square")

                PrivacyBlock(
                    title: "Deleting your data",
                    text: "Settings › Storage clears your recent history and the files Toolbox created. Deleting the app removes everything it stored.",
                    symbol: "trash")
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColors.background)
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// In-app privacy policy. This is a plain-language draft that matches how
/// the app behaves today; have it reviewed, and host a public copy, before
/// App Store submission (the store listing needs a privacy policy URL).
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                PrivacyBlock(
                    title: "Summary",
                    text: "Toolbox doesn't collect, store on a server, or sell your personal information. Your files are processed on your device.")

                PrivacyBlock(
                    title: "Information we collect",
                    text: "None. Toolbox has no account system and no analytics. Files you create and the app's settings stay on your iPhone.")

                PrivacyBlock(
                    title: "How your information is used",
                    text: "Documents, images, scans and text are processed on your device using Apple's frameworks, only to do what you asked (for example, compress a PDF).")

                PrivacyBlock(
                    title: "Sharing",
                    text: "Toolbox doesn't share your information with anyone. Files leave the app only when you share or save them yourself.")

                PrivacyBlock(
                    title: "Keeping and deleting data",
                    text: "Data stays on your iPhone until you delete it from Settings › Storage or delete the app.")

                PrivacyBlock(
                    title: "Changes",
                    text: "If this policy changes, the updated version will be shown here in the app.")

                PrivacyBlock(
                    title: "Contact",
                    text: "Questions about privacy: \(AppLinks.supportEmail)")
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColors.background)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

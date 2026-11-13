import SwiftUI

/// The "drop box" on Home. Tap for Photos / Files, or drop files onto it.
struct ImportDropZone: View {
    var isTargeted: Bool = false
    var isBusy: Bool = false
    var onPhotos: () -> Void
    var onFiles: () -> Void

    var body: some View {
        Menu {
            Button { onPhotos() } label: { Label("Photo Library", systemImage: "photo.on.rectangle") }
            Button { onFiles() } label: { Label("Files", systemImage: "folder") }
        } label: {
            zone
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel("Import a file")
        .accessibilityHint("Choose a PDF or photo to see what you can do with it")
        .animation(.snappy, value: isTargeted)
    }

    private var zone: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(isTargeted ? 0.22 : 0.12))
                    .frame(width: 56, height: 56)
                if isBusy {
                    ProgressView()
                } else {
                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "tray.and.arrow.down.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(AppColors.accent)
                        .symbolEffect(.bounce, value: isTargeted)
                }
            }

            VStack(spacing: 4) {
                Text(isTargeted ? "Drop to import" : "Import a file")
                    .appHeadline()
                Text("Drop a PDF or photo here, or tap to choose.\nWe'll show what you can do with it.")
                    .appSecondary()
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: AppSpacing.sm) {
                chip("PDF", "doc.fill")
                chip("Photos", "photo.fill")
                chip("QR codes", "qrcode")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
        .padding(.horizontal, AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(isTargeted ? AppColors.accent.opacity(0.10) : AppColors.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .strokeBorder(
                    isTargeted ? AppColors.accent : AppColors.accent.opacity(0.35),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: [7, 5])
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }

    private func chip(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(.caption, weight: .medium))
            .foregroundStyle(AppColors.secondary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 6)
            .background(AppColors.secondaryCard, in: Capsule())
    }
}

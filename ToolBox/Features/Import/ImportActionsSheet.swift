import SwiftUI

/// "What do you want to do with this?" — shown after something is
/// imported on Home. Lists only the tools that work with that file.
struct ImportActionsSheet: View {
    let media: ImportedMedia
    var onChoose: (Tool) -> Void
    var onCancel: () -> Void

    @State private var summary: (title: String, detail: String)
    @State private var previewImage: UIImage?

    init(media: ImportedMedia, onChoose: @escaping (Tool) -> Void, onCancel: @escaping () -> Void) {
        self.media = media
        self.onChoose = onChoose
        self.onCancel = onCancel
        _summary = State(initialValue: ImportService.initialSummary(for: media))
    }

    private var actions: [ImportAction] { ImportService.actions(for: media) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    fileHeader

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        SectionHeader(title: "What would you like to do?")
                        VStack(spacing: 0) {
                            ForEach(actions) { action in
                                Button { onChoose(action.tool) } label: {
                                    RecentFileRow(icon: action.icon, name: action.title, detail: action.subtitle)
                                }
                                .buttonStyle(.plain)
                                if action.id != actions.last?.id {
                                    Divider().padding(.leading, 62)
                                }
                            }
                        }
                        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                        )
                        .padding(.horizontal, AppSpacing.lg)
                    }

                    if media.skipped > 0 {
                        Text("\(media.skipped) other file\(media.skipped == 1 ? " was" : "s were") skipped — Toolbox works with one kind of file at a time.")
                            .appCaption()
                            .padding(.horizontal, AppSpacing.lg)
                    }
                }
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColors.background)
            .navigationTitle("Imported")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
        .task {
            async let fullSummary = ImportService.summary(for: media)
            async let image = ImportService.previewImage(for: media)
            let (loadedSummary, loadedImage) = await (fullSummary, image)
            self.summary = loadedSummary
            self.previewImage = loadedImage
        }
    }

    private var fileHeader: some View {
        HStack(spacing: AppSpacing.md) {
            Group {
                if let previewImage {
                    Image(uiImage: previewImage).resizable().scaledToFill()
                } else {
                    Image(systemName: media.kind == .pdf ? "doc.fill" : "photo.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppColors.accent)
                }
            }
            .frame(width: 60, height: 72)
            .background(AppColors.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.title).appHeadline().lineLimit(2)
                Text(summary.detail).appSecondary()
            }
            Spacer()
        }
        .padding(AppSpacing.lg)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.lg)
        .accessibilityElement(children: .combine)
    }
}

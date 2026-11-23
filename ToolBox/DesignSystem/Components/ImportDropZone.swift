import SwiftUI

// MARK: - Glass Modifiers

private struct HeroGlassModifier: ViewModifier {
    var isTargeted: Bool = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(
                            isTargeted ? AppColors.accent : Color.white.opacity(0.15),
                            lineWidth: isTargeted ? 2 : 1
                        )
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(
                            isTargeted ? AppColors.accent : Color.white.opacity(0.15),
                            lineWidth: isTargeted ? 2 : 1
                        )
                )
        }
    }
}

private struct GlassPillModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
        } else {
            content
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
        }
    }
}

private struct GlassCircleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .circle)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
        } else {
            content
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
        }
    }
}

// MARK: - ImportDropZone

/// High-craft Hero Import Card on Home.
/// When empty, displays a balanced, centered Liquid Glass card with direct "Browse Files" and "Photo Library" pills.
/// When a file is staged, smoothly transitions into a reusable workspace card with 32pt controls and 36pt tool pills.
struct ImportDropZone: View {
    var stagedMedia: ImportedMedia? = nil
    var thumbnail: UIImage? = nil
    var title: String = ""
    var detail: String = ""
    var isLoading: Bool = false
    var isTargeted: Bool = false
    var isBusy: Bool = false

    var onPhotos: () -> Void
    var onFiles: () -> Void
    var onAction: (Tool) -> Void
    var onShare: () -> Void
    var onClear: () -> Void

    var body: some View {
        Group {
            if let stagedMedia {
                stagedWorkspaceCard(media: stagedMedia)
            } else {
                heroEmptyCard
            }
        }
        .animation(.snappy, value: stagedMedia != nil)
    }

    // MARK: - Empty State (Hero Import Card)

    private var heroEmptyCard: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            // Centered Glass Icon Badge
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 52, height: 52)

                if isBusy {
                    ProgressView()
                } else {
                    Image(systemName: isTargeted ? "arrow.down.doc.fill" : "doc.badge.plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(isTargeted ? AppColors.accent : Color.white)
                        .symbolEffect(.bounce, value: isTargeted)
                }
            }
            .modifier(GlassCircleModifier())

            // Title & Subtitle
            VStack(spacing: 4) {
                Text(isTargeted ? "Drop Files Here" : "Import a File")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)

                Text("PDF, Photos, or Documents")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.65))
            }

            Spacer(minLength: 0)

            // Direct Action Pills
            HStack(spacing: 12) {
                Button {
                    onFiles()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Browse Files")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .modifier(GlassPillModifier())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Browse files")

                Button {
                    onPhotos()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Photo Library")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .modifier(GlassPillModifier())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Photo library")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 205)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture {
            onFiles()
        }
        .modifier(HeroGlassModifier(isTargeted: isTargeted))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Import drop zone")
    }

    // MARK: - Staged State (Staged File Workspace Card)

    private func stagedWorkspaceCard(media: ImportedMedia) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top Header Row: Status Tag & Glass Action Controls
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 6, height: 6)
                    Text("STAGED WORKSPACE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .tracking(1.2)
                }

                Spacer()

                // Replace Menu (32pt height)
                Menu {
                    Button { onFiles() } label: {
                        Label("Browse Files", systemImage: "folder")
                    }
                    Button { onPhotos() } label: {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Replace")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .modifier(GlassPillModifier())
                }

                // Clear Button (32pt x 32pt, high-contrast xmark)
                Button {
                    onClear()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .frame(width: 32, height: 32)
                        .modifier(GlassCircleModifier())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear staged file")
            }

            // File Info Row
            HStack(spacing: 14) {
                thumbnailView(media: media)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title.isEmpty ? media.items.first?.name ?? "Imported File" : title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(formatPill(for: media))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(AppColors.accentSoft, in: Capsule())

                        Text(detail.isEmpty ? "Ready" : detail)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                Spacer()
            }

            Divider()
                .overlay(Color.white.opacity(0.12))

            // Action Pills Row
            actionPillsRow(media: media)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .modifier(HeroGlassModifier())
    }

    private func thumbnailView(media: ImportedMedia) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.accentSoft)
                        .frame(width: 56, height: 56)
                    if isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: media.kind == .pdf ? "doc.fill" : "photo.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(AppColors.accent)
                    }
                }
            }

            if media.items.count > 1 {
                Text("\(media.items.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.accent, in: Capsule())
                    .offset(x: 4, y: 4)
            }
        }
    }

    // MARK: - Smart Action Pills

    private func actionPillsRow(media: ImportedMedia) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                switch media.kind {
                case .pdf:
                    if let compressTool = Tool.all.first(where: { $0.id == .compressPDF }) {
                        actionButton(tool: compressTool, title: "Compress PDF", icon: "doc.badge.arrow.up.fill")
                    }
                    if let ocrTool = Tool.all.first(where: { $0.id == .ocr }) {
                        actionButton(tool: ocrTool, title: "Extract Text", icon: "text.viewfinder")
                    }
                    shareButton

                case .image:
                    if let compressTool = Tool.all.first(where: { $0.id == .compressImage }) {
                        actionButton(tool: compressTool, title: "Compress Image", icon: "photo.badge.arrow.down.fill")
                    }
                    if let resizeTool = Tool.all.first(where: { $0.id == .resizeImage }) {
                        actionButton(tool: resizeTool, title: "Resize Image", icon: "arrow.up.left.and.arrow.down.right")
                    }
                    if let ocrTool = Tool.all.first(where: { $0.id == .ocr }) {
                        actionButton(tool: ocrTool, title: "Extract Text", icon: "text.viewfinder")
                    }
                    shareButton
                }
            }
            .padding(.trailing, 16)
            .padding(.vertical, 2)
        }
    }

    private func actionButton(tool: Tool, title: String, icon: String) -> some View {
        Button {
            onAction(tool)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .fixedSize(horizontal: true, vertical: false)
            .modifier(GlassPillModifier())
        }
        .buttonStyle(.plain)
    }

    private var shareButton: some View {
        Button {
            onShare()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                Text("Share")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .fixedSize(horizontal: true, vertical: false)
            .modifier(GlassPillModifier())
        }
        .buttonStyle(.plain)
    }

    private func formatPill(for media: ImportedMedia) -> String {
        switch media.kind {
        case .pdf:
            return "PDF"
        case .image:
            if media.items.count > 1 {
                return "\(media.items.count) PHOTOS"
            } else if let ext = media.items.first?.url.pathExtension.uppercased(), !ext.isEmpty {
                return ext
            } else {
                return "IMG"
            }
        }
    }
}

// MARK: - Previews

#Preview("Empty State") {
    ZStack(alignment: .top) {
        Color.black.ignoresSafeArea()

        RadialGradient(
            colors: [
                Color(red: 0.0, green: 0.63, blue: 0.61).opacity(0.40),
                Color(red: 0.12, green: 0.13, blue: 1.0).opacity(0.22),
                Color.black
            ],
            center: .top,
            startRadius: 10,
            endRadius: 320
        )
        .frame(height: 320)
        .ignoresSafeArea(edges: .top)

        VStack {
            ImportDropZone(
                onPhotos: {},
                onFiles: {},
                onAction: { _ in },
                onShare: {},
                onClear: {}
            )
            .padding(16)
            Spacer()
        }
    }
}

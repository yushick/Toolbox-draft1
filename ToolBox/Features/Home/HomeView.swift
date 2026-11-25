import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import QuickLook

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = HomeViewModel()
    @Query(sort: \ProcessedFile.createdAt, order: .reverse)
    private var recentFiles: [ProcessedFile]
    @Environment(\.modelContext) private var modelContext
    @State private var previewURL: URL?

    private var visibleRecentFiles: [ProcessedFile] {
        recentFiles.filter { FileService.exists($0) }
    }

    /// Set by the environment / coordinator
    var onSelectTool: (Tool) -> Void = { _ in }
    /// Called when the user picks an operation for an imported file.
    var onImport: (Tool, ImportedMedia) -> Void = { _, _ in }
    /// Switches to the full Tools tab.
    var onSeeAllTools: () -> Void = {}
    /// Switches to the full Files tab.
    var onSeeAllFiles: () -> Void = {}

    // Import State
    @State private var isFileImporterPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var isCameraPresented = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isDropTargeted = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AmbientCanvasBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        SearchBar(text: $viewModel.searchText)
                            .padding(.horizontal, AppSpacing.lg)

                        if viewModel.isSearching {
                            searchResultsSection
                        } else {
                            ImportDropZone(
                                stagedMedia: appState.stagedMedia,
                                thumbnail: appState.stagedThumbnail,
                                title: appState.stagedTitle,
                                detail: appState.stagedDetail,
                                isLoading: appState.isLoadingStaged,
                                isTargeted: isDropTargeted,
                                isBusy: viewModel.isImporting,
                                onPhotos: { isPhotoPickerPresented = true },
                                onFiles: { isFileImporterPresented = true },
                                onScanDocument: {
                                    if let scanTool = Tool.all.first(where: { $0.id == .scanDocument }) {
                                        onSelectTool(scanTool)
                                    }
                                },
                                onCamera: {
                                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                        isCameraPresented = true
                                    } else {
                                        viewModel.importAlert = "Camera is not available on this device."
                                    }
                                },
                                onAction: { tool in
                                    if let media = appState.stagedMedia {
                                        onImport(tool, media)
                                    }
                                },
                                onShare: {
                                    if let firstURL = appState.stagedMedia?.items.first?.url {
                                        ShareSheet.present([firstURL])
                                    }
                                },
                                onClear: {
                                    withAnimation(.snappy) {
                                        appState.clearStaged()
                                    }
                                }
                            )
                            .padding(.horizontal, AppSpacing.lg)
                            .dropDestination(for: DroppedFile.self) { files, _ in
                                guard !files.isEmpty else { return false }
                                finishImport(files.map { ImportService.item(for: $0.url) })
                                return true
                            } isTargeted: { isDropTargeted = $0 }

                            quickActionsSection

                            if !visibleRecentFiles.isEmpty {
                                recentSection
                            }
                        }
                    }
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("OneBox")
            .navigationBarTitleDisplayMode(.large)
            .modifier(NavigationSubtitleModifier(subtitle: "Useful tools. One place."))
            .animation(.snappy, value: viewModel.searchText)
            .modifier(importModifiers)
            .quickLookPreview($previewURL)
            .alert("Import", isPresented: Binding(
                get: { viewModel.importAlert != nil },
                set: { if !$0 { viewModel.importAlert = nil } })
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.importAlert ?? "")
            }
        }
    }

    // MARK: - Import

    private var importModifiers: some ViewModifier {
        ImportModifiers(
            isFileImporterPresented: $isFileImporterPresented,
            isPhotoPickerPresented: $isPhotoPickerPresented,
            isCameraPresented: $isCameraPresented,
            photoSelection: $photoSelection,
            isImporting: $viewModel.isImporting,
            onFinishImport: { items in
                finishImport(items)
            }
        )
    }

    private func finishImport(_ items: [ImportedItem]) {
        viewModel.isImporting = false
        guard let media = ImportService.makeMedia(from: items) else {
            items.forEach { try? FileManager.default.removeItem(at: $0.url.deletingLastPathComponent()) }
            viewModel.importAlert = items.isEmpty
                ? "That file couldn't be opened. If it's in iCloud, wait for it to download and try again."
                : "OneBox works with PDFs and images. That file type isn't supported yet."
            return
        }
        withAnimation(.snappy) {
            appState.stageMedia(media)
        }
    }

    private func handleToolSelection(_ tool: Tool) {
        if let media = appState.stagedMedia, tool.isCompatible(with: media) {
            onImport(tool, media)
        } else {
            onSelectTool(tool)
        }
    }

    private var recentSection: some View {
        let displayedFiles = Array(visibleRecentFiles.prefix(3))
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "Recent", actionTitle: "See All", action: onSeeAllFiles)
            VStack(spacing: 0) {
                ForEach(displayedFiles) { file in
                    Button {
                        if FileService.exists(file) {
                            previewURL = FileService.url(for: file)
                        }
                    } label: {
                        RecentFileRow(icon: icon(for: file),
                                      name: file.filename,
                                      detail: file.createdAt.relativeDescription)
                    }
                    .buttonStyle(.plain)
                    if file.id != displayedFiles.last?.id {
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
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "Quick Actions", actionTitle: "All Tools", action: onSeeAllTools)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppSpacing.md),
                    GridItem(.flexible(), spacing: AppSpacing.md)
                ],
                spacing: AppSpacing.md
            ) {
                ForEach(viewModel.quickActions) { tool in
                    Button { handleToolSelection(tool) } label: {
                        QuickToolTile(tool: tool)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if viewModel.searchResults.isEmpty {
                EmptyState(icon: "magnifyingglass", title: "No tools found",
                           message: "Try a different search term.")
                .frame(height: 260)
            } else {
                ForEach(Set(viewModel.searchResults.map(\.category)).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { category in
                    SectionHeader(title: category.rawValue)
                    VStack(spacing: 0) {
                        ForEach(viewModel.searchResults.filter { $0.category == category }) { tool in
                            Button { handleToolSelection(tool) } label: {
                                RecentFileRow(icon: tool.icon, name: tool.title, detail: tool.subtitle)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppRadius.medium))
                    .padding(.horizontal, AppSpacing.lg)
                }
            }
        }
    }

    private func icon(for file: ProcessedFile) -> String {
        switch ProcessedFileKind(rawValue: file.kind) {
        case .pdf: return "doc.fill"
        case .image: return "photo.fill"
        case .text: return "text.alignleft"
        case .none: return "doc"
        }
    }
}

private extension Date {
    /// "2 minutes ago" / "Yesterday" style string, matching the spec's
    /// Recent Activity examples, without pulling in a dependency.
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}

/// All the import picker plumbing for Home, kept out of the main view body.
private struct ImportModifiers: ViewModifier {
    @Binding var isFileImporterPresented: Bool
    @Binding var isPhotoPickerPresented: Bool
    @Binding var isCameraPresented: Bool
    @Binding var photoSelection: [PhotosPickerItem]
    @Binding var isImporting: Bool
    var onFinishImport: ([ImportedItem]) -> Void

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $isFileImporterPresented,
                          allowedContentTypes: [.pdf, .image],
                          allowsMultipleSelection: true) { result in
                guard case .success(let urls) = result, !urls.isEmpty else { return }
                isImporting = true
                Task {
                    let items = await Task.detached { ImportService.stagePicked(urls) }.value
                    onFinishImport(items)
                }
            }
            .photosPicker(isPresented: $isPhotoPickerPresented,
                          selection: $photoSelection,
                          maxSelectionCount: 50,
                          selectionBehavior: .ordered,
                          matching: .images)
            .fullScreenCover(isPresented: $isCameraPresented) {
                CameraPicker { image in
                    isCameraPresented = false
                    guard let image else { return }
                    isImporting = true
                    Task {
                        let items: [ImportedItem] = await Task.detached {
                            guard let data = image.jpegData(compressionQuality: 0.92) else { return [] }
                            let rawTemp = FileManager.default.temporaryDirectory
                                .appendingPathComponent("Photo-\(UUID().uuidString.prefix(6)).jpg")
                            do {
                                try data.write(to: rawTemp, options: .atomic)
                                defer { try? FileManager.default.removeItem(at: rawTemp) }
                                let stagedURL = try ImportService.copyIn(rawTemp)
                                return [ImportService.item(for: stagedURL)]
                            } catch {
                                return []
                            }
                        }.value
                        onFinishImport(items)
                    }
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoSelection) { _, selection in
                guard !selection.isEmpty else { return }
                photoSelection = []
                isImporting = true
                Task {
                    var items: [ImportedItem] = []
                    for picked in selection {
                        if let file = try? await picked.loadTransferable(type: PickedImageFile.self) {
                            items.append(ImportedItem(url: file.url, name: file.name))
                        }
                    }
                    onFinishImport(items)
                }
            }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    var onComplete: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onComplete: (UIImage?) -> Void

        init(onComplete: @escaping (UIImage?) -> Void) {
            self.onComplete = onComplete
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onComplete(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onComplete(nil)
        }
    }
}

private struct QuickToolTile: View {
    let tool: Tool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Image(tool.assetImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .blendMode(.screen)

            VStack(alignment: .leading, spacing: 2) {
                Text(tool.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .lineLimit(1)

                Text(tool.subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppColors.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

private struct NavigationSubtitleModifier: ViewModifier {
    let subtitle: String

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.navigationSubtitle(subtitle)
        } else {
            content
        }
    }
}

#Preview {
    HomeView()
        .environment(AppState())
        .modelContainer(for: [RecentItem.self, ProcessedFile.self], inMemory: true)
}

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import QuickLook

struct HomeView: View {
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

    // Import State
    @State private var isFileImporterPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isDropTargeted = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                GeometryReader { proxy in
                    let height = proxy.size.height * 0.38
                    RadialGradient(
                        colors: [
                            Color(red: 0.0, green: 0.63, blue: 0.61).opacity(0.40), // #00A19B deep teal
                            Color(red: 0.12, green: 0.13, blue: 1.0).opacity(0.22), // #1E22FF indigo
                            Color.black
                        ],
                        center: .top,
                        startRadius: 10,
                        endRadius: height
                    )
                    .frame(height: height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        header
                        SearchBar(text: $viewModel.searchText)
                            .padding(.horizontal, AppSpacing.lg)

                        if viewModel.isSearching {
                            searchResultsSection
                        } else {
                            ImportDropZone(
                                stagedMedia: viewModel.stagedMedia,
                                thumbnail: viewModel.stagedThumbnail,
                                title: viewModel.stagedTitle,
                                detail: viewModel.stagedDetail,
                                isLoading: viewModel.isLoadingStaged,
                                isTargeted: isDropTargeted,
                                isBusy: viewModel.isImporting,
                                onPhotos: { isPhotoPickerPresented = true },
                                onFiles: { isFileImporterPresented = true },
                                onAction: { tool in
                                    if let media = viewModel.stagedMedia {
                                        onImport(tool, media)
                                    }
                                },
                                onShare: {
                                    if let firstURL = viewModel.stagedMedia?.items.first?.url {
                                        ShareSheet.present([firstURL])
                                    }
                                },
                                onClear: {
                                    withAnimation(.snappy) {
                                        viewModel.clearStaged()
                                    }
                                }
                            )
                            .padding(.horizontal, AppSpacing.lg)

                            if !visibleRecentFiles.isEmpty {
                                recentSection
                            }
                            toolsSections
                        }
                    }
                    .padding(.vertical, AppSpacing.lg)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
            photoSelection: $photoSelection,
            isDropTargeted: $isDropTargeted,
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
                : "Toolbox works with PDFs and images. That file type isn't supported yet."
            return
        }
        withAnimation(.snappy) {
            viewModel.stageMedia(media)
        }
    }

    private func handleToolSelection(_ tool: Tool) {
        if let media = viewModel.stagedMedia, isCompatible(tool: tool, media: media) {
            onImport(tool, media)
        } else {
            onSelectTool(tool)
        }
    }

    private func isCompatible(tool: Tool, media: ImportedMedia) -> Bool {
        switch media.kind {
        case .pdf:
            return tool.id == .compressPDF || tool.id == .ocr
        case .image:
            return tool.id == .compressImage || tool.id == .resizeImage || tool.id == .ocr || tool.id == .qrBarcodeScanner
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.greeting).appSecondary()
            Text("Toolbox").appLargeTitle()
            Text("Useful tools. One place.").appSecondary()
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private var recentSection: some View {
        let displayedFiles = Array(visibleRecentFiles.prefix(5))
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "Recent")
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

    private var toolsSections: some View {
        ForEach(ToolCategory.allCases, id: \.self) { category in
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SectionHeader(title: category.rawValue)

                // Primary (hero) tools for this category get the large card.
                ForEach(viewModel.primaryTools.filter { $0.category == category }) { tool in
                    Button { handleToolSelection(tool) } label: {
                        LargeToolCard(tool: tool)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppSpacing.lg)
                }

                // Remaining tools shown two-up in an adaptive grid.
                let secondary = viewModel.tools(in: category)
                if !secondary.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: AppSpacing.md),
                                         GridItem(.flexible(), spacing: AppSpacing.md)],
                              spacing: AppSpacing.md) {
                        ForEach(secondary) { tool in
                            Button { handleToolSelection(tool) } label: {
                                ToolCard(tool: tool)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
            }
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
    @Binding var photoSelection: [PhotosPickerItem]
    @Binding var isDropTargeted: Bool
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
            .dropDestination(for: DroppedFile.self) { files, _ in
                guard !files.isEmpty else { return false }
                onFinishImport(files.map { ImportService.item(for: $0.url) })
                return true
            } isTargeted: { isDropTargeted = $0 }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [RecentItem.self, ProcessedFile.self], inMemory: true)
}

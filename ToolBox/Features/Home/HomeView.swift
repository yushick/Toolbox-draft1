import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Query(sort: \RecentItem.timestamp, order: .reverse)
    private var recentItems: [RecentItem]
    @Environment(\.modelContext) private var modelContext

    /// Set by the environment / coordinator; kept simple here as a
    /// closure so Stage 1 doesn't need full navigation wired yet.
    var onSelectTool: (Tool) -> Void = { _ in }
    /// Called when the user picks an operation for an imported file.
    var onImport: (Tool, ImportedMedia) -> Void = { _, _ in }

    // Import
    @State private var importedMedia: ImportedMedia?
    @State private var pendingChoice: (tool: Tool, media: ImportedMedia)?
    @State private var isFileImporterPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isDropTargeted = false
    @State private var isImporting = false
    @State private var importAlert: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    header
                    SearchBar(text: $viewModel.searchText)
                        .padding(.horizontal, AppSpacing.lg)

                    if viewModel.isSearching {
                        searchResultsSection
                    } else {
                        ImportDropZone(isTargeted: isDropTargeted, isBusy: isImporting,
                                       onPhotos: { isPhotoPickerPresented = true },
                                       onFiles: { isFileImporterPresented = true })
                            .padding(.horizontal, AppSpacing.lg)
                        if !recentItems.isEmpty {
                            recentSection
                        }
                        toolsSections
                    }
                }
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColors.background)
            .navigationBarHidden(true)
            .animation(.snappy, value: viewModel.searchText)
            .modifier(importModifiers)
        }
    }

    // MARK: - Import

    private var importModifiers: some ViewModifier {
        ImportModifiers(
            importedMedia: $importedMedia,
            pendingChoice: $pendingChoice,
            isFileImporterPresented: $isFileImporterPresented,
            isPhotoPickerPresented: $isPhotoPickerPresented,
            photoSelection: $photoSelection,
            isDropTargeted: $isDropTargeted,
            isImporting: $isImporting,
            alertMessage: $importAlert,
            onImport: onImport
        )
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
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "Recent")
            VStack(spacing: 0) {
                ForEach(recentItems.prefix(3)) { item in
                    RecentFileRow(icon: iconFor(item), name: item.summary,
                                  detail: item.timestamp.relativeDescription)
                    if item.id != recentItems.prefix(3).last?.id {
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
                    Button { onSelectTool(tool) } label: {
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
                            Button { onSelectTool(tool) } label: {
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
                            Button { onSelectTool(tool) } label: {
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

    private func iconFor(_ item: RecentItem) -> String {
        Tool.all.first(where: { $0.id.rawValue == item.toolID })?.icon ?? "clock"
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

/// All the import plumbing for Home, kept out of the main view body.
private struct ImportModifiers: ViewModifier {
    @Binding var importedMedia: ImportedMedia?
    @Binding var pendingChoice: (tool: Tool, media: ImportedMedia)?
    @Binding var isFileImporterPresented: Bool
    @Binding var isPhotoPickerPresented: Bool
    @Binding var photoSelection: [PhotosPickerItem]
    @Binding var isDropTargeted: Bool
    @Binding var isImporting: Bool
    @Binding var alertMessage: String?
    var onImport: (Tool, ImportedMedia) -> Void

    /// Tracks what the sheet showed, so it can be cleaned up if dismissed.
    @State private var lastShown: ImportedMedia?

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $isFileImporterPresented,
                          allowedContentTypes: [.pdf, .image],
                          allowsMultipleSelection: true) { result in
                guard case .success(let urls) = result, !urls.isEmpty else { return }
                isImporting = true
                Task {
                    let items = await Task.detached { ImportService.stagePicked(urls) }.value
                    finish(items)
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
                    finish(items)
                }
            }
            .dropDestination(for: DroppedFile.self) { files, _ in
                guard !files.isEmpty else { return false }
                finish(files.map { ImportService.item(for: $0.url) })
                return true
            } isTargeted: { isDropTargeted = $0 }
            .sheet(item: $importedMedia, onDismiss: {
                if let choice = pendingChoice {
                    pendingChoice = nil
                    onImport(choice.tool, choice.media)
                } else if let media = lastShown {
                    ImportService.discard(media)
                }
                lastShown = nil
            }) { media in
                ImportActionsSheet(
                    media: media,
                    onChoose: { tool in
                        pendingChoice = (tool, media)
                        importedMedia = nil
                    },
                    onCancel: { importedMedia = nil }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .alert("Import", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } })
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "")
            }
    }

    private func finish(_ items: [ImportedItem]) {
        isImporting = false
        guard let media = ImportService.makeMedia(from: items) else {
            items.forEach { try? FileManager.default.removeItem(at: $0.url.deletingLastPathComponent()) }
            alertMessage = items.isEmpty
                ? "That file couldn't be opened. If it's in iCloud, wait for it to download and try again."
                : "Toolbox works with PDFs and images. That file type isn't supported yet."
            return
        }
        lastShown = media
        importedMedia = media
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [RecentItem.self, ProcessedFile.self], inMemory: true)
}
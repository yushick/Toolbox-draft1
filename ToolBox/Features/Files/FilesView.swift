import SwiftUI
import SwiftData
import QuickLook

/// Saved document library backed by `ProcessedFile`: search, type filter,
/// sort, live thumbnails, QuickLook preview, swipe/context actions, and batch selection.
struct FilesView: View {
    @Query(sort: \ProcessedFile.createdAt, order: .reverse)
    private var files: [ProcessedFile]

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = FilesViewModel()
    @AppStorage("filesSort") private var sortRaw = FileSort.newest.rawValue

    private var sort: FileSort { FileSort(rawValue: sortRaw) ?? .newest }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AmbientCanvasBackground()

                content

                if viewModel.isSelecting && !viewModel.selectedFileIDs.isEmpty {
                    batchActionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: viewModel.isSelecting)
            .animation(.snappy, value: viewModel.selectedFileIDs.count)
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !files.isEmpty {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button(viewModel.isSelecting ? "Done" : "Select") {
                            withAnimation(.snappy) {
                                if viewModel.isSelecting {
                                    viewModel.endSelection()
                                } else {
                                    viewModel.isSelecting = true
                                }
                            }
                        }

                        if !viewModel.isSelecting {
                            sortMenu
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search files")
            .quickLookPreview($viewModel.previewURL)
            .confirmationDialog(
                "Delete this file?",
                isPresented: Binding(get: { viewModel.fileToDelete != nil },
                                     set: { if !$0 { viewModel.fileToDelete = nil } }),
                titleVisibility: .visible,
                presenting: viewModel.fileToDelete
            ) { file in
                Button("Delete", role: .destructive) { viewModel.delete(file, in: modelContext) }
                Button("Cancel", role: .cancel) { }
            } message: { file in
                Text("“\(file.filename)” will be permanently deleted from OneBox. This can't be undone.")
            }
            .confirmationDialog(
                "Delete \(viewModel.selectedFileIDs.count) file\(viewModel.selectedFileIDs.count == 1 ? "" : "s")?",
                isPresented: $viewModel.showBatchDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Selected", role: .destructive) {
                    viewModel.batchDelete(from: files, in: modelContext)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("These files will be permanently deleted from OneBox. This can't be undone.")
            }
            .alert("Rename File", isPresented: Binding(
                get: { viewModel.fileToRename != nil },
                set: { if !$0 { viewModel.fileToRename = nil } })
            ) {
                TextField("Name", text: $viewModel.renameText)
                Button("Save") { viewModel.commitRename() }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let file = viewModel.fileToRename, !FileService.fileExtension(of: file).isEmpty {
                    Text("The .\(FileService.fileExtension(of: file)) extension stays the same.")
                }
            }
            .alert("Files", isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } })
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let visible = viewModel.visibleFiles(from: files, sort: sort)
        let sections = viewModel.sections(from: files, sort: sort)

        if files.isEmpty {
            EmptyState(
                icon: "folder",
                title: "No files yet",
                message: "Files you create with OneBox's tools will appear here."
            )
        } else {
            List {
                // Top Storage Footprint + Type Filter Strip
                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text(viewModel.totalSizeDescription(of: visible))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.secondary)
                            .padding(.horizontal, 4)

                        ScrollView(.horizontal) {
                            HStack(spacing: AppSpacing.sm) {
                                ForEach(FileTypeFilter.allCases) { filter in
                                    LiquidGlassFilterChip(
                                        title: filter.rawValue,
                                        isSelected: viewModel.selectedFilter == filter
                                    ) {
                                        withAnimation(.snappy) {
                                            viewModel.selectedFilter = filter
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .scrollIndicators(.hidden)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                if sections.isEmpty {
                    Section {
                        EmptyState(
                            icon: "magnifyingglass",
                            title: "No results",
                            message: viewModel.searchText.isEmpty
                                ? "No \(viewModel.selectedFilter.rawValue.lowercased()) files saved yet."
                                : "No files match “\(viewModel.searchText)”."
                        )
                        .frame(minHeight: 260)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } else {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.files) { file in
                                row(for: file)
                                    .listRowBackground(AppColors.card)
                            }
                        } header: {
                            if let title = section.title {
                                Text(title.uppercased())
                                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                                    .foregroundStyle(AppColors.secondary)
                                    .tracking(0.5)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                if viewModel.isSelecting && !viewModel.selectedFileIDs.isEmpty {
                    Color.clear.frame(height: 68)
                }
            }
        }
    }

    private func row(for file: ProcessedFile) -> some View {
        let exists = FileService.exists(file)
        let isSelected = viewModel.selectedFileIDs.contains(file.id)

        return Button {
            if viewModel.isSelecting {
                viewModel.toggleSelection(for: file)
            } else {
                viewModel.preview(file)
            }
        } label: {
            FileThumbnailRow(
                file: file,
                exists: exists,
                isSelecting: viewModel.isSelecting,
                isSelected: isSelected,
                iconName: icon(for: file),
                formatBadge: formatBadge(for: file),
                detailText: detail(for: file, exists: exists)
            )
            .opacity(exists ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !viewModel.isSelecting {
                Button(role: .destructive) {
                    viewModel.fileToDelete = file
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                if exists {
                    Button {
                        viewModel.beginRename(file)
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(AppColors.accent)
                }
            }
        }
        .swipeActions(edge: .leading) {
            if !viewModel.isSelecting && exists {
                Button {
                    viewModel.share(file)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(.blue)
            }
        }
        .contextMenu {
            if exists {
                Button { viewModel.preview(file) } label: { Label("Preview", systemImage: "eye") }
                Button { viewModel.share(file) } label: { Label("Share", systemImage: "square.and.arrow.up") }
                Button { viewModel.beginRename(file) } label: { Label("Rename", systemImage: "pencil") }
                Button { viewModel.openInFiles(file) } label: { Label("Open in Files", systemImage: "folder") }
            }
            Button(role: .destructive) { viewModel.fileToDelete = file } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(viewModel.isSelecting ? "Toggles selection" : (exists ? "Opens a preview" : ""))
    }

    private var batchActionBar: some View {
        HStack(spacing: AppSpacing.md) {
            Button {
                viewModel.batchShare(from: files)
            } label: {
                Label("Share (\(viewModel.selectedFileIDs.count))", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .modifier(BatchActionGlassModifier(tint: AppColors.accent.opacity(0.25)))
            }
            .buttonStyle(.plain)

            Button {
                viewModel.showBatchDeleteConfirmation = true
            } label: {
                Label("Delete (\(viewModel.selectedFileIDs.count))", systemImage: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.destructive)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .modifier(BatchActionGlassModifier(tint: AppColors.destructive.opacity(0.20)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.md)
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortRaw) {
                ForEach(FileSort.allCases) { option in
                    Text(option.rawValue).tag(option.rawValue)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Sort")
    }

    // MARK: - Row details

    private func detail(for file: ProcessedFile, exists: Bool) -> String {
        guard exists else { return "File missing" }
        let size = ByteCountFormatter.string(fromByteCount: Int64(file.byteSize), countStyle: .file)
        let relative = RelativeDateTimeFormatter().localizedString(for: file.createdAt, relativeTo: .now)
        return "\(size) · \(relative)"
    }

    private func formatBadge(for file: ProcessedFile) -> String {
        let ext = FileService.fileExtension(of: file).uppercased()
        if !ext.isEmpty { return ext }
        switch ProcessedFileKind(rawValue: file.kind) {
        case .pdf: return "PDF"
        case .image: return "IMG"
        case .text: return "TXT"
        case .none: return "FILE"
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

// MARK: - Scannable Thumbnail Row

private struct FileThumbnailRow: View {
    let file: ProcessedFile
    let exists: Bool
    let isSelecting: Bool
    let isSelected: Bool
    let iconName: String
    let formatBadge: String
    let detailText: String

    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? AppColors.accent : AppColors.secondary)
            }

            thumbnailPreview

            VStack(alignment: .leading, spacing: 4) {
                Text(file.filename)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(formatBadge)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.accentSoft, in: Capsule())

                    Text(detailText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColors.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if !isSelecting && exists {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.tertiary)
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .task(id: file.id) {
            guard exists, thumbnail == nil else { return }
            let url = FileService.url(for: file)
            thumbnail = await FilesViewModel.loadThumbnail(for: url, kindRaw: file.kind)
        }
    }

    @ViewBuilder
    private var thumbnailPreview: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(.rect(cornerRadius: 10))
        } else {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppColors.accent)
                .frame(width: 44, height: 44)
                .background(AppColors.accentSoft, in: .rect(cornerRadius: 10))
        }
    }
}

private struct BatchActionGlassModifier: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(tint).interactive(), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                }
        }
    }
}

#Preview {
    FilesView()
        .modelContainer(for: [ProcessedFile.self, RecentItem.self], inMemory: true)
}

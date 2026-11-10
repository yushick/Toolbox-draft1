import SwiftUI
import SwiftData
import QuickLook

/// Stage 8: everything Toolbox has created. Search, sort, preview
/// (Quick Look), rename, share, open in the Files app, and delete.
struct FilesView: View {
    @Query(sort: \ProcessedFile.createdAt, order: .reverse)
    private var files: [ProcessedFile]

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = FilesViewModel()
    @AppStorage("filesSort") private var sortRaw = FileSort.newest.rawValue

    private var sort: FileSort { FileSort(rawValue: sortRaw) ?? .newest }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Files")
                .toolbar {
                    if !files.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) { sortMenu }
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
                    Text("“\(file.filename)” will be permanently deleted from Toolbox. This can't be undone.")
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
        let sections = viewModel.sections(from: files, sort: sort)

        if files.isEmpty {
            EmptyState(
                icon: "folder",
                title: "No files yet",
                message: "Files you create with Toolbox's tools will appear here."
            )
        } else if sections.isEmpty {
            EmptyState(
                icon: "magnifyingglass",
                title: "No results",
                message: "No files match “\(viewModel.searchText)”."
            )
        } else {
            List {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.files) { file in
                            row(for: file)
                        }
                    } header: {
                        if let title = section.title { Text(title) }
                    }
                }

                Text(viewModel.totalSizeDescription(of: viewModel.visibleFiles(from: files, sort: sort)))
                    .appCaption()
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .listRowBackground(Color.clear)
            }
        }
    }

    private func row(for file: ProcessedFile) -> some View {
        let exists = FileService.exists(file)
        return Button {
            viewModel.preview(file)
        } label: {
            FileRow(icon: icon(for: file),
                    name: file.filename,
                    sizeDescription: detail(for: file, exists: exists))
                .opacity(exists ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
        .swipeActions(edge: .leading) {
            if exists {
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
        .accessibilityHint(exists ? "Opens a preview" : "")
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
        return "\(size) · \(file.createdAt.formatted(date: .omitted, time: .shortened))"
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

#Preview {
    FilesView()
        .modelContainer(for: [ProcessedFile.self, RecentItem.self], inMemory: true)
}

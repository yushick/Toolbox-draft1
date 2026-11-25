import SwiftUI

enum ToolDirectoryCategory: String, CaseIterable, Identifiable {
    case imageTools = "Image Tools"
    case pdfTools = "PDF Tools"
    case scanAndOCR = "Scan & OCR"
    case favorites = "Favorites"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .imageTools: return "photo"
        case .pdfTools: return "doc.text"
        case .scanAndOCR: return "viewfinder"
        case .favorites: return "star.fill"
        }
    }

    var assetImage: ImageResource {
        switch self {
        case .imageTools: return .categoryImages
        case .pdfTools: return .categoryPDF
        case .scanAndOCR: return .categoryScanOCR
        case .favorites: return .categoryFavorites
        }
    }

    var subtitle: String {
        switch self {
        case .imageTools: return "Resize, compress, and extract text"
        case .pdfTools: return "Scan, compress, and read PDFs"
        case .scanAndOCR: return "Scan documents, OCR, and QR codes"
        case .favorites: return "Your pinned tools"
        }
    }

    func tools(favoriteIDs: Set<String>) -> [Tool] {
        switch self {
        case .imageTools:
            let ids: [ToolID] = [.compressImage, .resizeImage, .ocr, .qrBarcodeScanner]
            return ids.compactMap { id in Tool.all.first { $0.id == id } }
        case .pdfTools:
            let ids: [ToolID] = [.scanDocument, .compressPDF, .ocr]
            return ids.compactMap { id in Tool.all.first { $0.id == id } }
        case .scanAndOCR:
            let ids: [ToolID] = [.scanDocument, .ocr, .qrBarcodeScanner]
            return ids.compactMap { id in Tool.all.first { $0.id == id } }
        case .favorites:
            return Tool.all.filter { favoriteIDs.contains($0.id.rawValue) }
        }
    }
}

struct ToolsView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var useStagedMedia = false
    @AppStorage("favoriteToolIDs") private var favoriteToolIDsRaw = "scanDocument,compressPDF"

    private var favoriteIDs: Set<String> {
        Set(favoriteToolIDsRaw.split(separator: ",").map(String.init))
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchResults: [Tool] {
        Tool.search(searchText)
    }

    private var popularTools: [Tool] {
        let ids: [ToolID] = [.scanDocument, .compressPDF, .compressImage, .ocr]
        return ids.compactMap { id in Tool.all.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AmbientCanvasBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        SearchBar(text: $searchText, placeholder: "Search for a tool")
                            .padding(.horizontal, AppSpacing.lg)

                        if let staged = appState.stagedMedia, !isSearching {
                            stagedHandoffSection(staged: staged)
                        }

                        if isSearching {
                            searchResultsSection
                        } else if useStagedMedia, let staged = appState.stagedMedia {
                            prioritizedToolsSections(for: staged)
                        } else {
                            categoriesSection
                            popularToolsSection
                        }
                    }
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.xl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: appState.stagedMedia == nil) { _, isEmpty in
                if isEmpty {
                    useStagedMedia = false
                }
            }
        }
    }

    // MARK: - Staged Handoff Pill

    private func stagedHandoffSection(staged: ImportedMedia) -> some View {
        let labelTitle = appState.stagedTitle.isEmpty
            ? (staged.items.first?.name ?? "Staged File")
            : appState.stagedTitle

        return Button {
            withAnimation(.snappy) {
                useStagedMedia.toggle()
            }
        } label: {
            HStack(spacing: AppSpacing.md) {
                stagedThumbView(staged: staged)

                VStack(alignment: .leading, spacing: 2) {
                    Text(useStagedMedia ? "Using Staged File" : "Use Staged File")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(useStagedMedia ? AppColors.accent : AppColors.primary)

                    Text(labelTitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColors.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(useStagedMedia ? "Active" : "Tap to Prioritize")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(useStagedMedia ? .white : AppColors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        useStagedMedia ? AppColors.accent : AppColors.accentSoft,
                        in: Capsule()
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .modifier(StagedPillGlassModifier(isActive: useStagedMedia))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.lg)
    }

    @ViewBuilder
    private func stagedThumbView(staged: ImportedMedia) -> some View {
        if let thumb = appState.stagedThumbnail {
            Image(uiImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 34, height: 34)
                .clipShape(.rect(cornerRadius: 8))
        } else {
            Image(systemName: staged.kind == .pdf ? "doc.fill" : "photo.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 34, height: 34)
                .background(AppColors.accentSoft, in: .rect(cornerRadius: 8))
        }
    }

    // MARK: - Categories Grid

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Categories")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.secondary)
                .padding(.horizontal, AppSpacing.lg)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppSpacing.md),
                    GridItem(.flexible(), spacing: AppSpacing.md)
                ],
                spacing: AppSpacing.md
            ) {
                ForEach(ToolDirectoryCategory.allCases) { category in
                    NavigationLink {
                        ToolCategoryDetailView(
                            category: category,
                            useStagedMedia: $useStagedMedia,
                            favoriteToolIDsRaw: $favoriteToolIDsRaw
                        )
                    } label: {
                        CategoryGridCard(category: category)
                    }
                    .buttonStyle(ScalePressButtonStyle())
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    // MARK: - Popular Tools Cards

    private var popularToolsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Most Popular")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.secondary)
                .padding(.horizontal, AppSpacing.lg)

            VStack(spacing: 10) {
                ForEach(popularTools) { tool in
                    toolRowButton(tool: tool, badgeTitle: nil, useStaged: false)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    // MARK: - Staged Prioritized Sections

    private func prioritizedToolsSections(for staged: ImportedMedia) -> some View {
        let compatible = Tool.all.filter { $0.isCompatible(with: staged) }
        let others = Tool.all.filter { !$0.isCompatible(with: staged) }
        let titleName = appState.stagedTitle.isEmpty ? "Staged File" : appState.stagedTitle

        return VStack(alignment: .leading, spacing: AppSpacing.xl) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Recommended for \(titleName)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.secondary)
                    .padding(.horizontal, AppSpacing.lg)

                VStack(spacing: 10) {
                    ForEach(compatible) { tool in
                        toolRowButton(tool: tool, badgeTitle: "Staged", useStaged: true)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }

            if !others.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Other Tools (Starts Fresh)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.secondary)
                        .padding(.horizontal, AppSpacing.lg)

                    VStack(spacing: 10) {
                        ForEach(others) { tool in
                            toolRowButton(tool: tool, badgeTitle: nil, useStaged: false)
                        }
                    }
                    .opacity(0.65)
                    .padding(.horizontal, AppSpacing.lg)
                }
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if searchResults.isEmpty {
                EmptyState(
                    icon: "magnifyingglass",
                    title: "No tools found",
                    message: "Try a different search term."
                )
                .frame(height: 260)
            } else {
                VStack(spacing: 10) {
                    ForEach(searchResults) { tool in
                        let shouldUseStaged = useStagedMedia
                            && appState.stagedMedia.map { tool.isCompatible(with: $0) } ?? false
                        toolRowButton(
                            tool: tool,
                            badgeTitle: shouldUseStaged ? "Staged" : nil,
                            useStaged: shouldUseStaged
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    private func toolRowButton(tool: Tool, badgeTitle: String?, useStaged: Bool) -> some View {
        let isFavorite = favoriteIDs.contains(tool.id.rawValue)

        return Button {
            if useStaged, let staged = appState.stagedMedia {
                appState.present(tool, with: staged)
            } else {
                appState.present(tool)
            }
        } label: {
            ToolRowCard(tool: tool, badgeTitle: badgeTitle)
        }
        .buttonStyle(ScalePressButtonStyle())
        .contextMenu {
            Button {
                toggleFavorite(tool.id)
            } label: {
                Label(
                    isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: isFavorite ? "star.slash" : "star"
                )
            }
        }
    }

    private func toggleFavorite(_ id: ToolID) {
        var set = favoriteIDs
        if set.contains(id.rawValue) {
            set.remove(id.rawValue)
        } else {
            set.insert(id.rawValue)
        }
        favoriteToolIDsRaw = set.sorted().joined(separator: ",")
    }
}

// MARK: - Category Detail View (List / Grid Toggle)

private struct ToolCategoryDetailView: View {
    let category: ToolDirectoryCategory
    @Binding var useStagedMedia: Bool
    @Binding var favoriteToolIDsRaw: String

    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @AppStorage("toolsDetailIsGridMode") private var isGridMode = true

    private var favoriteIDs: Set<String> {
        Set(favoriteToolIDsRaw.split(separator: ",").map(String.init))
    }

    private var displayedTools: [Tool] {
        let base = category.tools(favoriteIDs: favoriteIDs)
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = q.isEmpty
            ? base
            : base.filter { $0.title.lowercased().contains(q) || $0.subtitle.lowercased().contains(q) }

        if useStagedMedia, let staged = appState.stagedMedia {
            return filtered.sorted { lhs, rhs in
                lhs.isCompatible(with: staged) && !rhs.isCompatible(with: staged)
            }
        }
        return filtered
    }

    var body: some View {
        ZStack(alignment: .top) {
            AmbientCanvasBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    SearchBar(text: $searchText, placeholder: "Search in \(category.rawValue)")
                        .padding(.horizontal, AppSpacing.lg)

                    if displayedTools.isEmpty {
                        EmptyState(
                            icon: category == .favorites ? "star" : "magnifyingglass",
                            title: category == .favorites ? "No Favorites Yet" : "No tools found",
                            message: category == .favorites
                                ? "Long-press any tool and tap Add to Favorites."
                                : "Try a different search term."
                        )
                        .frame(height: 260)
                    } else if isGridMode {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: AppSpacing.md),
                                GridItem(.flexible(), spacing: AppSpacing.md)
                            ],
                            spacing: AppSpacing.md
                        ) {
                            ForEach(displayedTools) { tool in
                                detailButton(for: tool) {
                                    ToolGridCard(tool: tool)
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(displayedTools) { tool in
                                let badge = (useStagedMedia && appState.stagedMedia.map { tool.isCompatible(with: $0) } == true)
                                    ? "Staged"
                                    : nil
                                detailButton(for: tool) {
                                    ToolRowCard(tool: tool, badgeTitle: badge)
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                    }
                }
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(
                    isGridMode ? "List View" : "Grid View",
                    systemImage: isGridMode ? "list.bullet" : "square.grid.2x2"
                ) {
                    withAnimation(.snappy) {
                        isGridMode.toggle()
                    }
                }
            }
        }
    }

    private func detailButton<ButtonContent: View>(for tool: Tool, @ViewBuilder label: () -> ButtonContent) -> some View {
        let isFavorite = favoriteIDs.contains(tool.id.rawValue)
        return Button {
            if useStagedMedia, let staged = appState.stagedMedia, tool.isCompatible(with: staged) {
                appState.present(tool, with: staged)
            } else {
                appState.present(tool)
            }
        } label: {
            label()
        }
        .buttonStyle(ScalePressButtonStyle())
        .contextMenu {
            Button {
                var set = favoriteIDs
                if set.contains(tool.id.rawValue) {
                    set.remove(tool.id.rawValue)
                } else {
                    set.insert(tool.id.rawValue)
                }
                favoriteToolIDsRaw = set.sorted().joined(separator: ",")
            } label: {
                Label(
                    isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: isFavorite ? "star.slash" : "star"
                )
            }
        }
    }
}

// MARK: - Card Components

private struct CategoryGridCard: View {
    let category: ToolDirectoryCategory

    var body: some View {
        VStack(spacing: 12) {
            Image(category.assetImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 58, height: 58)
                .blendMode(.screen)

            Text(category.rawValue)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, minHeight: 132)
        .modifier(ToolsCardGlassModifier())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

private struct ToolGridCard: View {
    let tool: Tool

    var body: some View {
        VStack(spacing: 12) {
            Image(tool.assetImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
                .blendMode(.screen)

            Text(tool.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, minHeight: 130)
        .modifier(ToolsCardGlassModifier())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

private struct ToolRowCard: View {
    let tool: Tool
    var badgeTitle: String? = nil

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(tool.assetImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 42, height: 42)
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

            Spacer()

            if let badgeTitle {
                Text(badgeTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.accentSoft, in: Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
        .modifier(ToolsCardGlassModifier())
        .contentShape(Rectangle())
    }
}

/// Lightweight 120Hz translucent dark glass card surface that lets the ambient
/// background glow shine through without per-card interactive backdrop passes.
private struct ToolsCardGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.20), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
    }
}

private struct ScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}

private struct StagedPillGlassModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    isActive ? .regular.tint(AppColors.accent.opacity(0.25)).interactive() : .regular.interactive(),
                    in: .rect(cornerRadius: 16)
                )
        } else {
            content
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isActive ? AppColors.accent.opacity(0.6) : Color.white.opacity(0.15),
                            lineWidth: 1
                        )
                }
        }
    }
}

#Preview {
    ToolsView()
        .environment(AppState())
}

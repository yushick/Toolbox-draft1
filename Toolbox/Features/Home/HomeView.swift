import SwiftUI
import SwiftData

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Query(sort: \RecentItem.timestamp, order: .reverse)
    private var recentItems: [RecentItem]
    @Environment(\.modelContext) private var modelContext

    /// Set by the environment / coordinator; kept simple here as a
    /// closure so Stage 1 doesn't need full navigation wired yet.
    var onSelectTool: (Tool) -> Void = { _ in }

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

#Preview {
    HomeView()
        .modelContainer(for: [RecentItem.self, ProcessedFile.self], inMemory: true)
}

import SwiftUI
import SwiftData
import StoreKit

/// Stage 9: Settings. Appearance and processing defaults take effect
/// immediately and are remembered between launches.
struct SettingsView: View {
    @AppStorage(PreferenceKey.appearance) private var appearance: AppAppearance = .system
    @AppStorage(PreferenceKey.imageQuality) private var imageQuality = AppPreferences.fallbackImageQuality
    @AppStorage(PreferenceKey.pdfCompression) private var pdfCompression: CompressionQuality = .balanced

    @Query private var files: [ProcessedFile]
    @Query private var recentItems: [RecentItem]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                processingSection
                privacySection
                storageSection
                aboutSection
            }
            .navigationTitle("Settings")
            .confirmationDialog("Clear recent history?",
                                isPresented: $viewModel.isConfirmingHistory,
                                titleVisibility: .visible) {
                Button("Clear History", role: .destructive) { viewModel.clearRecentHistory(in: modelContext) }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This empties the Recent list on Home. Your files aren't affected.")
            }
            .confirmationDialog("Delete all generated files?",
                                isPresented: $viewModel.isConfirmingFiles,
                                titleVisibility: .visible) {
                Button("Delete \(files.count) File\(files.count == 1 ? "" : "s")", role: .destructive) {
                    viewModel.clearGeneratedFiles(files, in: modelContext)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This permanently deletes every file Toolbox created (\(viewModel.totalSizeDescription(of: files))). Files you already shared or saved elsewhere aren't affected. This can't be undone.")
            }
            .alert("Settings", isPresented: Binding(
                get: { viewModel.message != nil },
                set: { if !$0 { viewModel.message = nil } })
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.message ?? "")
            }
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appearance) {
                ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var processingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text("Default Image Quality")
                    Spacer()
                    Text("\(Int((imageQuality * 100).rounded()))%").foregroundStyle(AppColors.secondary)
                }
                Slider(value: $imageQuality, in: 0.1...1.0, step: 0.05)
                    .accessibilityLabel("Default image quality")
                    .accessibilityValue("\(Int((imageQuality * 100).rounded())) percent")
            }
            .padding(.vertical, AppSpacing.xs)

            Picker("Default PDF Compression", selection: $pdfCompression) {
                ForEach(CompressionQuality.allCases) { Text($0.rawValue).tag($0) }
            }
        } header: {
            Text("Processing")
        } footer: {
            Text("Starting values for the compressors. You can still change them each time.")
        }
    }

    private var privacySection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Your files stay on your iPhone.").appHeadline()
                Text("Toolbox processes your documents, images and scans locally whenever possible. We don't upload your files to a server.")
                    .appSecondary()
            }
            .padding(.vertical, AppSpacing.xs)
            NavigationLink("Data & Privacy") { DataPrivacyView() }
            NavigationLink("Privacy Policy") { PrivacyPolicyView() }
        } header: {
            Text("Privacy")
        }
    }

    private var storageSection: some View {
        Section {
            LabeledContent("Generated Files", value: viewModel.totalSizeDescription(of: files))

            Button("Clear Recent History", role: .destructive) {
                viewModel.isConfirmingHistory = true
            }
            .disabled(recentItems.isEmpty)

            Button("Clear Generated Files", role: .destructive) {
                viewModel.isConfirmingFiles = true
            }
            .disabled(files.isEmpty)
        } header: {
            Text("Storage")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: AppInfo.versionString)

            Button("Rate Toolbox") {
                if let url = AppLinks.reviewURL { openURL(url) } else { requestReview() }
            }

            Button("Contact Support") {
                if let url = AppLinks.supportURL { openURL(url) }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [ProcessedFile.self, RecentItem.self], inMemory: true)
}

import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @AppStorage(PreferenceKey.appearance) private var appearance: AppAppearance = .system
    @AppStorage(OnboardingState.completedKey) private var hasCompletedOnboarding = false

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView(onSelectTool: { appState.present($0) },
                     onImport: { appState.present($0, with: $1) })
                .tabItem { Label("Home", systemImage: "square.grid.2x2") }
                .tag(AppState.Tab.home)

            FilesView()
                .tabItem { Label("Files", systemImage: "folder") }
                .tag(AppState.Tab.files)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppState.Tab.settings)
        }
        .tint(AppColors.accent)
        .preferredColorScheme(appearance.colorScheme)
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } })
        ) {
            OnboardingView { hasCompletedOnboarding = true }
                .preferredColorScheme(appearance.colorScheme)
        }
        .sheet(item: $appState.presentedTool, onDismiss: { appState.importedMedia = nil }) { tool in
            ToolDestination(tool: tool, media: appState.importedMedia)
                // Sheets are presented separately, so give them the theme too.
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}

/// Routes a selected Tool to its feature screen. Each destination is a
/// Stage-2-onward feature; for now unbuilt stages show a lightweight
/// placeholder rather than a fake/working-looking screen (see rule
/// against "placeholder functionality pretending it works" — this
/// placeholder is honest about being unbuilt, it doesn't simulate output).
private struct ToolDestination: View {
    let tool: Tool
    var media: ImportedMedia? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch tool.id {
                case .scanDocument: ScannerFlowView()
                case .compressPDF: PDFCompressorFlowView(imported: media)
                case .compressImage: ImageCompressorFlowView(imported: media)
                case .resizeImage: ImageResizerFlowView(imported: media)
                case .qrBarcodeScanner: QRScannerFlowView(imported: media)
                case .ocr: OCRFlowView(imported: media)
                }
            }
            .navigationTitle(tool.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

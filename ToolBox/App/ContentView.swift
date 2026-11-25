import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @State private var isQuickMenuOpen = false
    @AppStorage(PreferenceKey.appearance) private var appearance: AppAppearance = .system
    @AppStorage(OnboardingState.completedKey) private var hasCompletedOnboarding = false

    private var tabSelection: Binding<AppState.Tab> {
        Binding(
            get: { appState.selectedTab },
            set: { newValue in
                if newValue == .quickActions {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        isQuickMenuOpen.toggle()
                    }
                } else {
                    appState.selectedTab = newValue
                    if isQuickMenuOpen {
                        withAnimation(.snappy) {
                            isQuickMenuOpen = false
                        }
                    }
                }
            }
        )
    }

    var body: some View {
        ZStack {
            tabBarContent
                .environment(appState)

            QuickActionsOverlay(
                isOpen: isQuickMenuOpen,
                onSelectTool: { tool in
                    isQuickMenuOpen = false
                    appState.present(tool)
                },
                onDismiss: {
                    isQuickMenuOpen = false
                }
            )
            .zIndex(10)
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

    @ViewBuilder
    private var tabBarContent: some View {
        let baseTabs = TabView(selection: tabSelection) {
            Tab("Home", systemImage: "square.grid.2x2", value: AppState.Tab.home) {
                HomeView(onSelectTool: { appState.present($0) },
                         onImport: { appState.present($0, with: $1) },
                         onSeeAllTools: { appState.selectedTab = .tools },
                         onSeeAllFiles: { appState.selectedTab = .files })
            }

            Tab("Tools", systemImage: "wrench.and.screwdriver", value: AppState.Tab.tools) {
                ToolsView()
            }

            Tab("Files", systemImage: "folder", value: AppState.Tab.files) {
                FilesView()
            }

            if #available(iOS 27.0, *) {
                Tab("Quick", systemImage: "wrench.and.screwdriver", value: AppState.Tab.quickActions, role: .prominent) {
                    Color.clear
                }
            } else {
                Tab("Quick", systemImage: "wrench.and.screwdriver", value: AppState.Tab.quickActions) {
                    Color.clear
                }
            }
        }

        if #available(iOS 26.0, *) {
            baseTabs.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            baseTabs
        }
    }
}

// MARK: - Floating Quick Actions Overlay

private struct QuickActionsOverlay: View {
    let isOpen: Bool
    var onSelectTool: (Tool) -> Void
    var onDismiss: () -> Void

    private var handyTools: [Tool] {
        let ids: [ToolID] = [.scanDocument, .compressPDF, .compressImage, .resizeImage, .ocr]
        return ids.compactMap { id in Tool.all.first { $0.id == id } }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black.opacity(isOpen ? 0.50 : 0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.22), value: isOpen)
                .onTapGesture {
                    onDismiss()
                }

            VStack(alignment: .trailing, spacing: 10) {
                ForEach(Array(handyTools.enumerated()), id: \.element.id) { index, tool in
                    let reverseIndex = handyTools.count - 1 - index
                    let delay = isOpen
                        ? Double(reverseIndex) * 0.045
                        : Double(index) * 0.03

                    QuickActionFloatingRow(tool: tool) {
                        onSelectTool(tool)
                    }
                    .opacity(isOpen ? 1 : 0)
                    .offset(y: isOpen ? 0 : CGFloat(reverseIndex + 1) * 34)
                    .scaleEffect(isOpen ? 1 : 0.74, anchor: .bottomTrailing)
                    .animation(
                        .spring(response: 0.36, dampingFraction: 0.78).delay(delay),
                        value: isOpen
                    )
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 82)
        }
        .allowsHitTesting(isOpen)
    }
}

private struct QuickActionFloatingRow: View {
    let tool: Tool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(tool.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(tool.subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .modifier(QuickMenuGlassCapsuleModifier())

                Image(systemName: tool.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .modifier(QuickMenuGlassCircleModifier())
            }
        }
        .buttonStyle(.plain)
    }
}

private struct QuickMenuGlassCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                }
        }
    }
}

private struct QuickMenuGlassCircleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                }
        }
    }
}

/// Routes a selected Tool to its feature screen.
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

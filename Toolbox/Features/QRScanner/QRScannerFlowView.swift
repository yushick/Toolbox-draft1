import SwiftUI
import PhotosUI
import SwiftData

/// Stage 6: QR & Barcode scanner. Live camera scanning with a flashlight
/// toggle, plus scanning a code from an existing photo.
struct QRScannerFlowView: View {
    @State private var viewModel = QRScannerViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .task { await viewModel.prepareCamera() }
            .onChange(of: scenePhase) { _, phase in
                // Coming back from Settings after changing camera access.
                if phase == .active, viewModel.cameraState == .denied || viewModel.cameraState == .checking {
                    Task { await viewModel.prepareCamera() }
                }
            }
            .photosPicker(isPresented: $viewModel.isPhotoPickerPresented,
                          selection: $viewModel.photoSelection,
                          matching: .images)
            .onChange(of: viewModel.photoSelection) { _, item in
                if let item { Task { await viewModel.scanPhoto(item) } }
            }
            .sheet(item: $viewModel.result, onDismiss: { viewModel.resultDismissed() }) { code in
                ScanResultView(code: code)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: viewModel.result?.id) { _, newID in
                guard newID != nil else { return }
                modelContext.insert(RecentItem(toolID: .qrBarcodeScanner, summary: "Code scanned"))
                try? modelContext.save()
            }
            .alert("QR & Barcode", isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } })
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .onDisappear { viewModel.stopTorch() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.cameraState {
        case .checking:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)

        case .ready:
            cameraScreen

        case .needsPermission:
            fallbackScreen(
                EmptyState(icon: "camera", title: "Camera Access",
                           message: "Toolbox needs your camera to scan codes. Video stays on your iPhone and is never recorded or uploaded.",
                           actionTitle: "Allow Camera") {
                    Task { await viewModel.requestCameraAccess() }
                })

        case .denied:
            fallbackScreen(
                EmptyState(icon: "camera.badge.ellipsis", title: "Camera Access Is Off",
                           message: "Allow camera access in Settings to scan codes live. You can still scan a code from a photo.",
                           actionTitle: "Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                })

        case .unsupported:
            fallbackScreen(
                EmptyState(icon: "qrcode.viewfinder", title: "Live Scanning Isn't Available",
                           message: "This device can't scan with the camera. You can still scan a code from a photo."))
        }
    }

    // MARK: - Camera

    private var cameraScreen: some View {
        ZStack {
            DataScannerView(isScanning: viewModel.isScanning) { payload, symbology in
                viewModel.handleScan(payload: payload, symbologyRaw: symbology)
            }
            .ignoresSafeArea(edges: .bottom)

            VStack {
                HStack {
                    Spacer()
                    if TorchService.isAvailable { torchButton }
                }
                .padding(AppSpacing.lg)

                Spacer()

                VStack(spacing: AppSpacing.md) {
                    Text("Point your camera at a QR code or barcode")
                        .font(.system(.footnote, weight: .medium))
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.sm)
                        .background(.regularMaterial, in: Capsule())

                    Button {
                        viewModel.isPhotoPickerPresented = true
                    } label: {
                        Label("Scan from Photo", systemImage: "photo")
                            .font(.system(.subheadline, weight: .semibold))
                            .padding(.horizontal, AppSpacing.xl)
                            .frame(minHeight: 48)
                            .background(.regularMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }

    private var torchButton: some View {
        Button {
            viewModel.toggleTorch()
        } label: {
            Image(systemName: viewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(viewModel.isTorchOn ? AppColors.accent : AppColors.primary)
                .frame(width: 48, height: 48)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Flashlight")
        .accessibilityValue(viewModel.isTorchOn ? "On" : "Off")
    }

    // MARK: - Fallback

    private func fallbackScreen(_ state: EmptyState) -> some View {
        VStack(spacing: AppSpacing.md) {
            state
            SecondaryButton(title: "Scan from Photo", systemImage: "photo") {
                viewModel.isPhotoPickerPresented = true
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background)
    }
}

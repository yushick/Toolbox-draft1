import SwiftUI
import SwiftData
import VisionKit
import AVFoundation

/// Stage 2: the Document Scanner flow. Follows the spec's
/// Select → Configure → Process → Result → Share/Save shape, reusing
/// the shared ProcessingView/SuccessView components.
struct ScannerFlowView: View {
    @State private var viewModel = ScannerViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private enum CameraAccess { case available, unsupported, denied }

    /// The document camera needs real camera hardware and permission.
    private var cameraAccess: CameraAccess {
        guard VNDocumentCameraViewController.isSupported else { return .unsupported }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted: return .denied
        default: return .available
        }
    }

    var body: some View {
        content
            .fullScreenCover(isPresented: $viewModel.isCameraPresented) {
                DocumentCameraView(
                    onFinish: { viewModel.addPages($0) },
                    onCancel: { viewModel.cancelCamera() }
                )
                .ignoresSafeArea()
            }
            .onAppear {
                // Launch the camera immediately on first entry, since
                // there's nothing useful to review yet.
                if viewModel.pages.isEmpty && viewModel.stage == .review && cameraAccess == .available {
                    viewModel.isCameraPresented = true
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.stage {
        case .review:
            reviewScreen
        case .processing:
            ProcessingView(title: "Creating PDF", progress: nil,
                           detail: "\(viewModel.pages.count) page\(viewModel.pages.count == 1 ? "" : "s")")
        case .result(let fileURL, let filename, let byteCount):
            SuccessView(
                title: "Done",
                message: "Your document was saved as a PDF.",
                statBefore: nil, statAfter: ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file),
                statCaption: filename,
                onShare: { shareFile(fileURL) },
                onSaveToFiles: { shareFile(fileURL) }, // system share sheet includes "Save to Files"
                onDone: {
                    if viewModel.recordResult(fileURL: fileURL, filename: filename, byteCount: byteCount, in: modelContext) {
                        dismiss()
                    } else {
                        viewModel.stage = .failed(message: "The PDF was saved, but couldn't be added to your Files list. You can still find it via Share.")
                    }
                }
            )
        case .failed(let message):
            EmptyState(icon: "exclamationmark.triangle", title: "Couldn't create the PDF",
                       message: message, actionTitle: "Try Again") {
                viewModel.stage = .review
            }
        }
    }

    private var reviewScreen: some View {
        VStack(spacing: 0) {
            if viewModel.pages.isEmpty {
                switch cameraAccess {
                case .available:
                    EmptyState(icon: "doc.viewfinder", title: "No pages yet",
                               message: "Scan your first page and it will appear here.",
                               actionTitle: "Scan Page") {
                        viewModel.isCameraPresented = true
                    }
                case .unsupported:
                    EmptyState(icon: "camera.metering.unknown", title: "Camera Not Available",
                               message: "Document scanning needs a camera, which isn't available on this device.")
                case .denied:
                    EmptyState(icon: "camera.badge.ellipsis", title: "Camera Access Is Off",
                               message: "Allow camera access in Settings to scan documents.",
                               actionTitle: "Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            } else {
                List {
                    Section("Document Name") {
                        TextField("Document name", text: $viewModel.documentName)
                    }
                    Section("Scanned Document") {
                        ForEach(viewModel.pages) { page in
                            PageRow(page: page, enhancement: viewModel.enhancement) {
                                viewModel.retake(page)
                            }
                        }
                        .onDelete { viewModel.deletePages(at: $0) }
                        .onMove { viewModel.movePages(from: $0, to: $1) }
                    }
                }
                .listStyle(.insetGrouped)

                VStack(spacing: AppSpacing.md) {
                    Picker("Enhancement", selection: $viewModel.enhancement) {
                        ForEach(PageEnhancement.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: AppSpacing.md) {
                        SecondaryButton(title: "Add Page", systemImage: "plus") {
                            viewModel.isCameraPresented = true
                        }
                        PrimaryButton(title: "Create PDF", systemImage: "doc.badge.plus") {
                            Task { await viewModel.createPDF() }
                        }
                    }
                }
                .padding(AppSpacing.lg)
                .background(.bar)
            }
        }
        .toolbar {
            if !viewModel.pages.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
    }

    private func shareFile(_ url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController?
            .present(activityVC, animated: true)
    }
}

private struct PageRow: View {
    let page: ScannedPage
    let enhancement: PageEnhancement
    let onRetake: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(uiImage: DocumentScannerService.enhance(page.originalImage, mode: enhancement))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(AppColors.cardStroke, lineWidth: 1))

            Text("Page").appBody()
            Spacer()
            Button("Retake", action: onRetake)
                .font(.system(.footnote, weight: .semibold))
                .frame(minWidth: 44, minHeight: 44)
        }
    }
}

import SwiftUI
import UniformTypeIdentifiers
import SwiftData

/// Stage 3: PDF Compressor. Select → Configure → Process → Result,
/// reusing the shared ProcessingView/SuccessView components.
struct PDFCompressorFlowView: View {
    @State private var viewModel = PDFCompressorViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content
            .fileImporter(isPresented: $viewModel.isFileImporterPresented,
                          allowedContentTypes: [.pdf]) { result in
                switch result {
                case .success(let url): viewModel.handlePickedFile(url)
                case .failure: break
                }
            }
            .onAppear {
                if viewModel.stage == .pickFile && viewModel.sourceURL == nil {
                    viewModel.isFileImporterPresented = true
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.stage {
        case .pickFile:
            EmptyState(icon: "doc.badge.arrow.up", title: "Select a PDF",
                       message: "Choose a PDF from Files to compress.",
                       actionTitle: "Choose File") {
                viewModel.isFileImporterPresented = true
            }
        case .configure:
            configureScreen
        case .processing:
            ProcessingView(title: "Compressing PDF", progress: nil,
                           detail: ByteCountFormatter.string(fromByteCount: Int64(viewModel.originalBytes), countStyle: .file))
        case .result(let fileURL, let filename, let originalBytes, let compressedBytes):
            SuccessView(
                title: "Compression Complete",
                message: "Your PDF is ready.",
                statBefore: ByteCountFormatter.string(fromByteCount: Int64(originalBytes), countStyle: .file),
                statAfter: ByteCountFormatter.string(fromByteCount: Int64(compressedBytes), countStyle: .file),
                statCaption: savedCaption(original: originalBytes, compressed: compressedBytes),
                onShare: { shareFile(fileURL) },
                onSaveToFiles: { shareFile(fileURL) },
                onDone: {
                    if viewModel.recordResult(filename: filename, byteCount: compressedBytes, in: modelContext) {
                        dismiss()
                    } else {
                        viewModel.stage = .failed(message: "The PDF was saved, but couldn't be added to your Files list. You can still find it via Share.")
                    }
                }
            )
        case .failed(let message):
            EmptyState(icon: "exclamationmark.triangle", title: "Couldn't compress the PDF",
                       message: message, actionTitle: "Try Again") {
                viewModel.stage = .configure
            }
        }
    }

    private var configureScreen: some View {
        VStack(spacing: AppSpacing.xl) {
            VStack(spacing: AppSpacing.xs) {
                Text("Original Size").appSecondary()
                Text(ByteCountFormatter.string(fromByteCount: Int64(viewModel.originalBytes), countStyle: .file))
                    .font(.system(.title, design: .rounded, weight: .bold))
            }
            .padding(.top, AppSpacing.xl)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionHeader(title: "File Name")
                TextField("File name", text: $viewModel.outputName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, AppSpacing.lg)

                SectionHeader(title: "Quality").padding(.top, AppSpacing.sm)
                ForEach(CompressionQuality.allCases) { quality in
                    optionRow(title: quality.rawValue,
                              isSelected: isSelected(.quality(quality))) {
                        viewModel.mode = .quality(quality)
                    }
                }

                SectionHeader(title: "Target Size").padding(.top, AppSpacing.md)
                ForEach(TargetSize.presets) { target in
                    optionRow(title: target.label,
                              isSelected: isSelected(.targetSize(target))) {
                        viewModel.mode = .targetSize(target)
                    }
                }
                optionRow(title: "Custom", isSelected: isCustomSelected) {
                    viewModel.mode = .targetSize(.custom(Int(viewModel.customTargetMB * 1_000_000)))
                }
                if isCustomSelected {
                    HStack {
                        Slider(value: $viewModel.customTargetMB, in: 0.2...15, step: 0.1)
                        Text("\(viewModel.customTargetMB, specifier: "%.1f") MB")
                            .appSecondary()
                            .frame(width: 64, alignment: .trailing)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .onChange(of: viewModel.customTargetMB) { _, newValue in
                        viewModel.mode = .targetSize(.custom(Int(newValue * 1_000_000)))
                    }
                }
            }

            Spacer()

            PrimaryButton(title: "Compress", systemImage: "arrow.down.circle") {
                Task { await viewModel.compress(in: modelContext) }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .padding(.bottom, AppSpacing.lg)
    }

    private func isSelected(_ candidate: CompressionMode) -> Bool { viewModel.mode == candidate }
    private var isCustomSelected: Bool {
        if case .targetSize(.custom) = viewModel.mode { return true }
        return false
    }

    private func optionRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).appBody()
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColors.accent)
                } else {
                    Image(systemName: "circle").foregroundStyle(AppColors.secondary)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
        }
        .buttonStyle(.plain)
    }

    private func savedCaption(original: Int, compressed: Int) -> String {
        guard original > 0 else { return "" }
        let percent = Int((1 - Double(compressed) / Double(original)) * 100)
        return percent > 0 ? "Saved \(percent)%" : "No further reduction possible"
    }

    private func shareFile(_ url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController?
            .present(activityVC, animated: true)
    }
}

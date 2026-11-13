import SwiftUI
import PhotosUI
import SwiftData

/// Stage 4: Image Compressor. Select → Configure → Process → Result.
/// Uses PhotosPicker, which runs out-of-process, so no Photos
/// permission prompt is needed just to choose images.
struct ImageCompressorFlowView: View {
    @State private var viewModel = ImageCompressorViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var imported: ImportedMedia?

    init(imported: ImportedMedia? = nil) { self.imported = imported }

    var body: some View {
        content
            .photosPicker(isPresented: $viewModel.isPickerPresented,
                          selection: $viewModel.selection,
                          maxSelectionCount: 50,
                          selectionBehavior: .ordered,
                          matching: .images)
            .onChange(of: viewModel.selection) { _, _ in
                Task { await viewModel.loadSelection() }
            }
            .onAppear {
                if viewModel.stage == .pick && viewModel.images.isEmpty {
                    if let imported {
                        viewModel.preload(imported.items)
                    } else {
                        viewModel.isPickerPresented = true
                    }
                }
            }
            .alert("Image Compressor", isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } })
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.stage {
        case .pick:
            EmptyState(icon: "photo.badge.arrow.down", title: "Select Photos",
                       message: "Choose one or more photos to compress. They never leave your iPhone.",
                       actionTitle: "Choose Photos") {
                viewModel.isPickerPresented = true
            }
        case .loading:
            ProcessingView(title: "Preparing photos", progress: nil)
        case .configure:
            configureScreen
        case .processing(let done, let total):
            ProcessingView(title: "Compressing images",
                           progress: viewModel.progress,
                           detail: "Processing \(min(done + 1, total)) of \(total) images",
                           onCancel: { viewModel.cancelCompression() })
        case .result:
            resultScreen
        case .failed(let message):
            EmptyState(icon: "exclamationmark.triangle", title: "Couldn't compress the images",
                       message: message, actionTitle: "Try Again") {
                if viewModel.images.isEmpty {
                    viewModel.stage = .pick
                    viewModel.isPickerPresented = true
                } else {
                    viewModel.stage = .configure
                }
            }
        }
    }

    // MARK: - Configure

    private var configureScreen: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                Text("\(viewModel.images.count) Image\(viewModel.images.count == 1 ? "" : "s") Selected")
                    .appTitle()
                    .padding(.top, AppSpacing.lg)

                thumbnailStrip

                HStack(spacing: AppSpacing.md) {
                    sizeCard(title: "Original", value: viewModel.totalOriginalBytes.formattedBytes)
                    sizeCard(title: "Estimated",
                             value: viewModel.estimatedBytes?.formattedBytes ?? "Calculating…",
                             highlight: true)
                }
                .padding(.horizontal, AppSpacing.lg)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeader(title: "Quality")
                    VStack(spacing: AppSpacing.xs) {
                        Slider(value: $viewModel.quality, in: 0.1...1.0, step: 0.05)
                            .accessibilityLabel("Quality")
                            .accessibilityValue("\(Int(viewModel.quality * 100)) percent")
                        Text("\(Int(viewModel.quality * 100))%").appSecondary()
                    }
                    .padding(AppSpacing.lg)
                    .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                    .padding(.horizontal, AppSpacing.lg)
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeader(title: "Format")
                    Picker("Format", selection: $viewModel.format) {
                        ForEach(viewModel.availableFormats) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.lg)
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeader(title: "Resize")
                    HStack {
                        Text("Longest side").appBody()
                        Spacer()
                        Picker("Longest side", selection: $viewModel.maxDimension) {
                            ForEach(MaxDimension.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .frame(minHeight: 52)
                    .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                    .padding(.horizontal, AppSpacing.lg)
                    Text("Aspect ratio is always preserved. Images are never enlarged.")
                        .appCaption()
                        .padding(.horizontal, AppSpacing.lg)
                }

                PrimaryButton(title: "Compress", systemImage: "arrow.down.circle") {
                    viewModel.startCompression()
                }
                .padding(.horizontal, AppSpacing.lg)

                SecondaryButton(title: "Choose Different Photos", systemImage: "photo.on.rectangle") {
                    viewModel.isPickerPresented = true
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
            }
        }
        .background(AppColors.background)
        .onChange(of: viewModel.quality) { _, _ in viewModel.refreshEstimate() }
        .onChange(of: viewModel.format) { _, _ in viewModel.refreshEstimate() }
        .onChange(of: viewModel.maxDimension) { _, _ in viewModel.refreshEstimate() }
    }

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(viewModel.images) { image in
                    Group {
                        if let thumbnail = image.thumbnail {
                            Image(uiImage: thumbnail).resizable().scaledToFill()
                        } else {
                            Rectangle().fill(AppColors.secondaryCard)
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
                    .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    private func sizeCard(title: String, value: String, highlight: Bool = false) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(title).appCaption()
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(highlight ? AppColors.accent : AppColors.primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Result

    private var resultScreen: some View {
        SuccessView(
            title: "Compression Complete",
            message: viewModel.results.count == 1 ? "Your image is ready." : "Your \(viewModel.results.count) images are ready.",
            statBefore: viewModel.totalOriginalBytes.formattedBytes,
            statAfter: viewModel.totalCompressedBytes.formattedBytes,
            statCaption: viewModel.totalSavedBytes > 0
                ? "Saved \(viewModel.totalSavedBytes.formattedBytes)"
                : "No size reduction — try a lower quality",
            onShare: { viewModel.share() },
            onSaveToFiles: { Task { await viewModel.saveToPhotos() } },
            saveTitle: viewModel.results.count == 1 ? "Save Image" : "Save Images",
            saveIcon: "photo.badge.plus",
            extraContent: viewModel.results.count > 1 ? AnyView(resultList) : nil,
            onDone: {
                if viewModel.recordResults(in: modelContext) {
                    dismiss()
                } else {
                    viewModel.alertMessage = "Your images were saved, but couldn't be added to the Files list."
                }
            }
        )
    }

    private var resultList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(viewModel.results) { result in
                    HStack {
                        Text(result.filename).appBody().lineLimit(1)
                        Spacer()
                        Text("\(result.originalBytes.formattedBytes) → \(result.compressedBytes.formattedBytes)")
                            .appCaption()
                    }
                    .padding(.vertical, AppSpacing.sm)
                    .padding(.horizontal, AppSpacing.lg)
                    .frame(minHeight: 44)
                    Divider()
                }
            }
        }
        .frame(maxHeight: 180)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
    }
}

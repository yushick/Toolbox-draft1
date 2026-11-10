import SwiftUI
import PhotosUI
import SwiftData

/// Stage 5: Image Resizer. Select → Configure (with live preview) →
/// Process → Result. Reuses the shared components from earlier stages.
struct ImageResizerFlowView: View {
    @State private var viewModel = ImageResizerViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
                    viewModel.isPickerPresented = true
                }
            }
            .alert("Image Resizer", isPresented: Binding(
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
            EmptyState(icon: "arrow.up.left.and.arrow.down.right", title: "Select Photos",
                       message: "Choose one or more photos to resize. They never leave your iPhone.",
                       actionTitle: "Choose Photos") {
                viewModel.isPickerPresented = true
            }
        case .loading:
            ProcessingView(title: "Preparing photos", progress: nil)
        case .configure:
            configureScreen
        case .processing(let done, let total):
            ProcessingView(title: "Resizing images",
                           progress: viewModel.progress,
                           detail: "Processing \(min(done + 1, total)) of \(total) images",
                           onCancel: { viewModel.cancelResizing() })
        case .result:
            resultScreen
        case .failed(let message):
            EmptyState(icon: "exclamationmark.triangle", title: "Couldn't resize the images",
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

                ResizePreviewView(image: viewModel.previewImage,
                                  target: viewModel.targetSize,
                                  output: viewModel.previewOutputSize,
                                  mode: viewModel.mode)
                    .padding(.horizontal, AppSpacing.lg)

                presetSection
                if viewModel.preset == .custom { customSection }
                modeSection

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeader(title: "Format")
                    Picker("Format", selection: $viewModel.format) {
                        ForEach(viewModel.availableFormats) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.lg)
                }

                VStack(spacing: AppSpacing.sm) {
                    PrimaryButton(title: "Resize", systemImage: "arrow.up.left.and.arrow.down.right") {
                        viewModel.startResizing()
                    }
                    SecondaryButton(title: "Choose Different Photos", systemImage: "photo.on.rectangle") {
                        viewModel.isPickerPresented = true
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
            }
        }
        .background(AppColors.background)
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "Size")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(ResizePreset.allCases) { preset in
                        presetChip(preset)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    private func presetChip(_ preset: ResizePreset) -> some View {
        let isSelected = viewModel.preset == preset
        return Button {
            withAnimation(.snappy) { viewModel.select(preset) }
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                presetIcon(preset)
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.title)
                        .font(.system(.subheadline, weight: .semibold))
                    Text(preset.subtitle)
                        .font(.system(.caption))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : AppColors.secondary)
                }
            }
            .foregroundStyle(isSelected ? Color.white : AppColors.primary)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .frame(minWidth: 120, minHeight: 100, alignment: .topLeading)
            .background(isSelected ? AppColors.accent : AppColors.card,
                        in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.title), \(preset.subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Logo image if one was added to the asset catalog, otherwise an SF Symbol.
    /// Sits on a light tile so a full-colour logo reads on the selected chip too.
    @ViewBuilder
    private func presetIcon(_ preset: ResizePreset) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
            if let name = preset.logoAssetName, UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            } else {
                Image(systemName: preset.symbolName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppColors.accent)
            }
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "Custom Size")
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    dimensionField(title: "Width",
                                   value: Binding(get: { viewModel.customWidth },
                                                  set: { viewModel.setWidth($0) }))
                    Image(systemName: viewModel.lockAspectRatio ? "link" : "link.badge.plus")
                        .foregroundStyle(AppColors.secondary)
                        .accessibilityHidden(true)
                    dimensionField(title: "Height",
                                   value: Binding(get: { viewModel.customHeight },
                                                  set: { viewModel.setHeight($0) }))
                }
                Toggle("Lock aspect ratio",
                       isOn: Binding(get: { viewModel.lockAspectRatio },
                                     set: { viewModel.setLock($0) }))
                    .frame(minHeight: 44)
            }
            .padding(AppSpacing.lg)
            .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    private func dimensionField(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title).appCaption()
            TextField(title, value: value, format: .number.grouping(.never))
                .keyboardType(.numberPad)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .padding(.horizontal, AppSpacing.md)
                .frame(minHeight: 44)
                .background(AppColors.secondaryCard, in: RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
            Text("px").appCaption()
        }
        .frame(maxWidth: .infinity)
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "Resize Mode")
            Picker("Mode", selection: $viewModel.mode) {
                ForEach(ResizeMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.lg)
            Text(viewModel.mode.detail)
                .appCaption()
                .padding(.horizontal, AppSpacing.lg)
        }
    }

    // MARK: - Result

    private var resultScreen: some View {
        let single = viewModel.results.count == 1 ? viewModel.results.first : nil
        return SuccessView(
            title: "Resize Complete",
            message: single != nil ? "Your image is ready." : "Your \(viewModel.results.count) images are ready.",
            statBefore: single?.originalPixels.pixelDescription,
            statAfter: single?.newPixels.pixelDescription,
            statCaption: single.map { "\($0.newBytes.formattedBytes)" },
            onShare: { viewModel.share() },
            onSaveToFiles: { Task { await viewModel.saveToPhotos() } },
            saveTitle: single != nil ? "Save Image" : "Save Images",
            saveIcon: "photo.badge.plus",
            extraContent: single == nil ? AnyView(resultList) : nil,
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
                        Text(result.newPixels.pixelDescription).appCaption()
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

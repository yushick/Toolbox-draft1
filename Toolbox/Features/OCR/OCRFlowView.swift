import SwiftUI
import PhotosUI
import SwiftData

/// Stage 7: OCR. Scan with the camera or choose photos, read the text
/// on-device, edit it, then copy, share, or save it as TXT or PDF.
struct OCRFlowView: View {
    @State private var viewModel = OCRViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var copied = false

    var body: some View {
        content
            .fullScreenCover(isPresented: $viewModel.isCameraPresented) {
                DocumentCameraView(
                    onFinish: { viewModel.processCameraPages($0) },
                    onCancel: { viewModel.isCameraPresented = false }
                )
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $viewModel.isPhotoPickerPresented,
                          selection: $viewModel.photoSelection,
                          maxSelectionCount: 10,
                          selectionBehavior: .ordered,
                          matching: .images)
            .onChange(of: viewModel.photoSelection) { _, selection in
                if !selection.isEmpty { Task { await viewModel.processPhotos() } }
            }
            .onChange(of: viewModel.stage) { _, stage in
                if stage == .result {
                    modelContext.insert(RecentItem(toolID: .ocr, summary: "Text extracted"))
                    try? modelContext.save()
                }
            }
            .alert("Scan Text", isPresented: Binding(
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
            pickScreen
        case .processing(let done, let total):
            ProcessingView(title: "Reading text",
                           progress: viewModel.progress,
                           detail: total > 1 ? "Page \(min(done + 1, total)) of \(total)" : nil,
                           onCancel: { viewModel.cancel() })
        case .result:
            resultScreen
        case .failed(let message):
            EmptyState(icon: "text.viewfinder", title: "Couldn't read any text",
                       message: message, actionTitle: "Try Again") {
                viewModel.scanAnother()
            }
        }
    }

    // MARK: - Pick

    private var pickScreen: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            Image(systemName: "text.viewfinder")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(AppColors.accent)
                .accessibilityHidden(true)

            VStack(spacing: AppSpacing.xs) {
                Text("Scan Text").appTitle()
                Text("Point your camera at printed text, or pick photos that contain text. It's read on your iPhone and never uploaded.")
                    .appSecondary()
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.xl)

            Spacer()

            VStack(spacing: AppSpacing.sm) {
                PrimaryButton(title: "Scan with Camera", systemImage: "camera.viewfinder") {
                    viewModel.openCamera()
                }
                SecondaryButton(title: "Choose Photos", systemImage: "photo.on.rectangle") {
                    viewModel.isPhotoPickerPresented = true
                }
                Text(OCRService.supportsHindi
                     ? "Recognizes English, Hindi and other languages your device supports."
                     : "Recognizes English and other languages your device supports.")
                    .appCaption()
                    .multilineTextAlignment(.center)
                    .padding(.top, AppSpacing.xs)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.background)
    }

    // MARK: - Result

    private var resultScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        SectionHeader(title: "Text Detected")
                        Text("\(viewModel.wordCount) words").appCaption()
                            .padding(.trailing, AppSpacing.lg)
                    }
                    TextEditor(text: $viewModel.text)
                        .font(AppFont.body())
                        .scrollContentBackground(.hidden)
                        .padding(AppSpacing.md)
                        .frame(minHeight: 240)
                        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                        )
                        .padding(.horizontal, AppSpacing.lg)
                        .accessibilityLabel("Detected text, editable")
                    Text("Tap the text to fix any mistakes before copying or saving.")
                        .appCaption()
                        .padding(.horizontal, AppSpacing.lg)
                }

                VStack(spacing: AppSpacing.sm) {
                    PrimaryButton(title: copied ? "Copied" : "Copy All",
                                  systemImage: copied ? "checkmark" : "doc.on.doc") {
                        copyAll()
                    }
                    .disabled(isTextEmpty)

                    shareButton
                        .disabled(isTextEmpty)
                }
                .padding(.horizontal, AppSpacing.lg)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeader(title: "Save As File")
                    TextField("File name", text: $viewModel.fileName)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, AppSpacing.lg)

                    HStack(spacing: AppSpacing.md) {
                        SecondaryButton(title: "Save TXT", systemImage: "doc.text") {
                            dismissKeyboard()
                            viewModel.exportTXT(in: modelContext)
                        }
                        SecondaryButton(title: "Create PDF", systemImage: "doc.richtext") {
                            dismissKeyboard()
                            viewModel.exportPDF(in: modelContext)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .disabled(isTextEmpty)

                    if let status = viewModel.statusMessage {
                        Text(status)
                            .appSecondary()
                            .padding(.horizontal, AppSpacing.lg)
                    }
                }

                Button("Scan Something Else") { viewModel.scanAnother() }
                    .font(.system(.body, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.bottom, AppSpacing.lg)
            }
            .padding(.top, AppSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background)
    }

    private var isTextEmpty: Bool {
        viewModel.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shareButton: some View {
        ShareLink(item: viewModel.text) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "square.and.arrow.up")
                Text("Share").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
        }
        .buttonStyle(.bordered)
        .tint(AppColors.primary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
    }

    private func copyAll() {
        dismissKeyboard()
        UIPasteboard.general.string = viewModel.text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.snappy) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.snappy) { copied = false }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

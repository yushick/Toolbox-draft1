import Foundation
import SwiftUI
import PhotosUI
import Observation
import SwiftData

@MainActor
@Observable
final class ImageResizerViewModel {
    enum Stage: Equatable {
        case pick
        case loading
        case configure
        case processing(done: Int, total: Int)
        case result
        case failed(message: String)
    }

    var stage: Stage = .pick
    var isPickerPresented = false
    var selection: [PhotosPickerItem] = []

    var images: [PickedImage] = []
    var previewImage: UIImage?
    var firstPixelSize: CGSize = .zero

    var preset: ResizePreset = .instagramPost
    var mode: ResizeMode = .fill
    var format: ImageOutputFormat = .jpeg
    var lockAspectRatio = true
    private(set) var customWidth = 1080
    private(set) var customHeight = 1080
    private var aspectRatio: CGFloat = 1

    var results: [ResizedImageResult] = []
    var alertMessage: String?

    private var processingTask: Task<Void, Never>?
    private let quality = 0.9
    private let maxCustomSide = 8000

    // MARK: - Derived

    var availableFormats: [ImageOutputFormat] { ImageOutputFormat.allCases.filter(\.isSupported) }

    var targetSize: CGSize {
        preset.size ?? CGSize(width: customWidth, height: customHeight)
    }

    /// What the first image will become, used for the live preview.
    var previewOutputSize: CGSize {
        ImageResizeService.outputSize(source: firstPixelSize, target: targetSize, mode: mode)
    }

    var progress: Double {
        if case .processing(let done, let total) = stage, total > 0 { return Double(done) / Double(total) }
        return 0
    }

    // MARK: - Selection

    func loadSelection() async {
        guard !selection.isEmpty else { stage = .pick; return }
        stage = .loading
        var loaded: [PickedImage] = []
        for item in selection {
            guard let file = try? await item.loadTransferable(type: PickedImageFile.self) else { continue }
            loaded.append(PickedImage(url: file.url, name: file.name,
                                      originalBytes: ImageProcessingService.fileSize(at: file.url),
                                      thumbnail: ImageProcessingService.thumbnail(url: file.url)))
        }
        finishLoading(loaded)
    }

    /// Starts from files imported on Home (already in our temp folder).
    func preload(_ items: [ImportedItem]) {
        stage = .loading
        finishLoading(items.map {
            PickedImage(url: $0.url, name: $0.name,
                        originalBytes: ImageProcessingService.fileSize(at: $0.url),
                        thumbnail: ImageProcessingService.thumbnail(url: $0.url))
        })
    }

    private func finishLoading(_ loaded: [PickedImage]) {
        guard let first = loaded.first, let size = ImageResizeService.orientedPixelSize(of: first.url) else {
            stage = .failed(message: "None of the selected photos could be opened. They may be stored in iCloud and unavailable right now.")
            return
        }

        images = loaded
        firstPixelSize = size
        aspectRatio = size.width / size.height
        previewImage = ImageProcessingService.thumbnail(url: first.url, maxPixelSize: 800)

        // Start custom at the photo's own size, capped so it's a sensible default.
        let cap: CGFloat = 2048
        let factor = min(1, cap / max(size.width, size.height))
        customWidth = max(1, Int((size.width * factor).rounded()))
        customHeight = max(1, Int((size.height * factor).rounded()))

        if !availableFormats.contains(format) { format = .jpeg }
        stage = .configure
    }

    // MARK: - Configuration

    func select(_ preset: ResizePreset) {
        self.preset = preset
        mode = preset.defaultMode
    }

    func setWidth(_ value: Int) {
        customWidth = min(max(1, value), maxCustomSide)
        if lockAspectRatio { customHeight = min(max(1, Int((CGFloat(customWidth) / aspectRatio).rounded())), maxCustomSide) }
    }

    func setHeight(_ value: Int) {
        customHeight = min(max(1, value), maxCustomSide)
        if lockAspectRatio { customWidth = min(max(1, Int((CGFloat(customHeight) * aspectRatio).rounded())), maxCustomSide) }
    }

    func setLock(_ locked: Bool) {
        lockAspectRatio = locked
        if locked { setWidth(customWidth) }
    }

    // MARK: - Resize

    func startResizing() {
        let images = images
        let target = targetSize
        let mode = mode
        let format = format
        let quality = quality
        results = []
        stage = .processing(done: 0, total: images.count)

        processingTask = Task {
            var written: [URL] = []
            do {
                for (index, image) in images.enumerated() {
                    try Task.checkCancellation()
                    let sourceURL = image.url
                    let output = try await Task.detached(priority: .userInitiated) {
                        try ImageResizeService.resize(sourceURL: sourceURL, target: target, mode: mode,
                                                      format: format, quality: quality)
                    }.value
                    try Task.checkCancellation()

                    let url = try OutputFiles.write(output.data, name: "Resized \(image.name)", ext: format.fileExtension)
                    written.append(url)
                    results.append(ResizedImageResult(
                        fileURL: url, filename: url.lastPathComponent,
                        originalPixels: ImageResizeService.orientedPixelSize(of: sourceURL) ?? .zero,
                        newPixels: output.size,
                        originalBytes: image.originalBytes, newBytes: output.data.count))
                    stage = .processing(done: index + 1, total: images.count)
                }
                stage = .result
            } catch is CancellationError {
                written.forEach { try? FileManager.default.removeItem(at: $0) }
                results = []
                stage = .configure
            } catch {
                written.forEach { try? FileManager.default.removeItem(at: $0) }
                results = []
                stage = .failed(message: Self.friendlyMessage(for: error))
            }
        }
    }

    func cancelResizing() { processingTask?.cancel() }

    // MARK: - Output

    func share() { ShareSheet.present(results.map(\.fileURL)) }

    func saveToPhotos() async {
        switch await PhotoLibrarySaver.save(results.map(\.fileURL)) {
        case .saved(let count): alertMessage = count == 1 ? "Saved to Photos." : "Saved \(count) images to Photos."
        case .denied: alertMessage = "Toolbox doesn't have permission to add photos. You can allow it in Settings › Toolbox › Photos."
        case .failed: alertMessage = "Couldn't save to Photos. Please try again."
        }
    }

    @discardableResult
    func recordResults(in context: ModelContext) -> Bool {
        for result in results {
            context.insert(ProcessedFile(filename: result.filename, kind: .image,
                                         byteSize: result.newBytes, relativePath: result.fileURL.lastPathComponent))
        }
        context.insert(RecentItem(toolID: .resizeImage,
                                  summary: results.count == 1 ? "Image resized" : "\(results.count) images resized"))
        do { try context.save(); return true } catch { return false }
    }

    private static func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError {
            return "There isn't enough free storage on your iPhone to save these images."
        }
        return error.localizedDescription
    }
}

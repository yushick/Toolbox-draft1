import Foundation
import SwiftUI
import PhotosUI
import Photos
import Observation
import SwiftData

@MainActor
@Observable
final class ImageCompressorViewModel {
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
    var quality: Double = AppPreferences.defaultImageQuality
    var format: ImageOutputFormat = .jpeg
    var maxDimension: MaxDimension = .original

    var estimatedBytes: Int?
    var results: [CompressedImageResult] = []
    var alertMessage: String?

    private var estimateTask: Task<Void, Never>?
    private var processingTask: Task<Void, Never>?
    nonisolated(unsafe) private var stagedInputURLs: [URL] = []

    // MARK: - Derived

    var totalOriginalBytes: Int { images.reduce(0) { $0 + $1.originalBytes } }
    var totalCompressedBytes: Int { results.reduce(0) { $0 + $1.compressedBytes } }
    var totalSavedBytes: Int { max(0, totalOriginalBytes - totalCompressedBytes) }

    var availableFormats: [ImageOutputFormat] {
        ImageOutputFormat.allCases.filter(\.isSupported)
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
            stagedInputURLs.append(file.url)
            let bytes = ImageProcessingService.fileSize(at: file.url)
            loaded.append(PickedImage(url: file.url, name: file.name, originalBytes: bytes,
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
        guard !loaded.isEmpty else {
            stage = .failed(message: "None of the selected photos could be opened. They may be stored in iCloud and unavailable right now.")
            return
        }

        images = loaded
        if !availableFormats.contains(format) { format = .jpeg }
        stage = .configure
        refreshEstimate()
    }

    // MARK: - Estimate

    /// Estimates total output by really compressing the first image at
    /// the current settings and scaling by the observed ratio. Debounced
    /// so dragging the slider stays smooth.
    func refreshEstimate() {
        estimateTask?.cancel()
        guard let sample = images.first, sample.originalBytes > 0 else { estimatedBytes = nil; return }
        let url = sample.url
        let originalBytes = sample.originalBytes
        let total = totalOriginalBytes
        let format = format
        let quality = quality
        let maxPixels = maxDimension.pixels

        estimateTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let size = await Task.detached(priority: .utility) {
                try? ImageProcessingService.compress(sourceURL: url, format: format,
                                                     quality: quality, maxPixelSize: maxPixels).count
            }.value
            guard !Task.isCancelled, let size else { return }
            estimatedBytes = Int(Double(total) * Double(size) / Double(originalBytes))
        }
    }

    // MARK: - Compress

    func startCompression() {
        let images = images
        let format = format
        let quality = quality
        let maxPixels = maxDimension.pixels
        let fileExt = format.fileExtension
        results = []
        stage = .processing(done: 0, total: images.count)

        processingTask = Task {
            var written: [URL] = []
            do {
                for (index, image) in images.enumerated() {
                    try Task.checkCancellation()
                    let sourceURL = image.url
                    let imageName = image.name
                    let (url, compressedBytes) = try await Task.detached(priority: .userInitiated) {
                        let data = try ImageProcessingService.compress(sourceURL: sourceURL, format: format,
                                                                       quality: quality, maxPixelSize: maxPixels)
                        let outputURL = try OutputFiles.write(data, name: "Compressed \(imageName)", ext: fileExt)
                        return (outputURL, data.count)
                    }.value
                    try Task.checkCancellation()

                    written.append(url)
                    results.append(CompressedImageResult(fileURL: url, filename: url.lastPathComponent,
                                                         originalBytes: image.originalBytes,
                                                         compressedBytes: compressedBytes))
                    stage = .processing(done: index + 1, total: images.count)
                }
                stage = .result
            } catch is CancellationError {
                // Remove partial output so a cancelled run leaves nothing behind.
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

    func cancelCompression() {
        processingTask?.cancel()
    }

    // MARK: - Output

    func share() {
        ShareSheet.present(results.map(\.fileURL))
    }

    func saveToPhotos() async {
        let urls = results.map(\.fileURL)
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            alertMessage = "Toolbox doesn't have permission to add photos. You can allow it in Settings › Toolbox › Photos."
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for url in urls {
                    PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: url)
                }
            }
            alertMessage = urls.count == 1 ? "Saved to Photos." : "Saved \(urls.count) images to Photos."
        } catch {
            alertMessage = "Couldn't save to Photos. Please try again."
        }
    }

    /// Records metadata and saves explicitly (the sheet dismisses right after).
    @discardableResult
    func recordResults(in context: ModelContext) -> Bool {
        var firstRelativePath: String?
        var firstFileID: UUID?
        for (index, result) in results.enumerated() {
            let relativePath = result.fileURL.lastPathComponent
            let file = ProcessedFile(filename: result.filename, kind: .image,
                                     byteSize: result.compressedBytes, relativePath: relativePath)
            context.insert(file)
            if index == 0 {
                firstRelativePath = relativePath
                firstFileID = file.id
            }
        }
        context.insert(RecentItem(toolID: .compressImage,
                                  summary: results.count == 1 ? "Image compressed" : "\(results.count) images compressed",
                                  relativePath: firstRelativePath,
                                  fileID: firstFileID))
        do { try context.save(); return true } catch { return false }
    }

    func cleanupInputFiles() {
        for url in stagedInputURLs {
            PickedImageFile.remove(at: url)
        }
        stagedInputURLs.removeAll()
    }

    deinit {
        for url in stagedInputURLs {
            PickedImageFile.remove(at: url)
        }
    }

    // MARK: - Helpers

    private static func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError {
            return "There isn't enough free storage on your iPhone to save these images."
        }
        return error.localizedDescription
    }
}

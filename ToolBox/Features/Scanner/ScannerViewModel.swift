import UIKit
import SwiftUI
import Observation
import SwiftData

@MainActor
@Observable
final class ScannerViewModel {
    enum Stage: Equatable {
        case review
        case processing
        case result(fileURL: URL, filename: String, byteCount: Int)
        case failed(message: String)
    }

    var pages: [ScannedPage] = []
    var enhancement: PageEnhancement = .color {
        didSet {
            if oldValue != enhancement {
                updateAllThumbnails()
            }
        }
    }
    var documentName: String = ScannerViewModel.defaultName()
    var stage: Stage = .review
    var isCameraPresented = false

    /// Asynchronously generated and cached thumbnails for fast, hitch-free display.
    var thumbnails: [UUID: UIImage] = [:]
    private var rawThumbnails: [UUID: UIImage] = [:]
    private var thumbnailTask: Task<Void, Never>?

    var hasPages: Bool { !pages.isEmpty }

    func thumbnail(for page: ScannedPage) -> UIImage? {
        thumbnails[page.id]
    }

    func addPages(_ images: [UIImage]) {
        let newPages = images.map { ScannedPage(originalImage: $0) }
        pages.append(contentsOf: newPages)
        isCameraPresented = false
        generateThumbnails(for: newPages)
    }

    func cancelCamera() {
        isCameraPresented = false
    }

    func deletePages(at offsets: IndexSet) {
        let removedIDs = offsets.map { pages[$0].id }
        pages.remove(atOffsets: offsets)
        for id in removedIDs {
            thumbnails.removeValue(forKey: id)
            rawThumbnails.removeValue(forKey: id)
        }
    }

    func movePages(from source: IndexSet, to destination: Int) {
        pages.move(fromOffsets: source, toOffset: destination)
    }

    /// Removes a page and immediately reopens the camera so the user
    /// can recapture it — the spec's "Retake" action.
    func retake(_ page: ScannedPage) {
        thumbnails.removeValue(forKey: page.id)
        rawThumbnails.removeValue(forKey: page.id)
        pages.removeAll { $0.id == page.id }
        isCameraPresented = true
    }

    // MARK: - Thumbnail Generation

    private func updateAllThumbnails() {
        thumbnailTask?.cancel()
        let pagesToProcess = pages
        let currentMode = enhancement
        let existingRaw = rawThumbnails

        thumbnailTask = Task {
            for page in pagesToProcess {
                if Task.isCancelled { break }
                let raw: UIImage
                if let cached = existingRaw[page.id] {
                    raw = cached
                } else {
                    raw = Self.downsample(page.originalImage)
                }
                let enhanced = Self.processThumbnail(raw: raw, mode: currentMode)
                if Task.isCancelled { break }
                guard self.enhancement == currentMode else { break }
                self.rawThumbnails[page.id] = raw
                self.thumbnails[page.id] = enhanced
            }
        }
    }

    private func generateThumbnails(for newPages: [ScannedPage]) {
        guard !newPages.isEmpty else { return }
        let currentMode = enhancement

        Task {
            for page in newPages {
                if Task.isCancelled { break }
                let raw = Self.downsample(page.originalImage)
                let enhanced = Self.processThumbnail(raw: raw, mode: currentMode)
                if Task.isCancelled { break }
                guard self.enhancement == currentMode else { break }
                self.rawThumbnails[page.id] = raw
                self.thumbnails[page.id] = enhanced
            }
        }
    }

    private nonisolated static func downsample(_ image: UIImage, maxDimension: CGFloat = 180) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let aspect = size.width / size.height
        let targetSize: CGSize
        if aspect >= 1 {
            targetSize = CGSize(width: maxDimension, height: max(1, maxDimension / aspect))
        } else {
            targetSize = CGSize(width: max(1, maxDimension * aspect), height: maxDimension)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private nonisolated static func processThumbnail(raw: UIImage, mode: PageEnhancement) -> UIImage {
        DocumentScannerService.enhance(raw, mode: mode)
    }

    func createPDF() async {
        stage = .processing
        let baseName = Self.sanitized(documentName)
        let cgImages = pages.compactMap { $0.originalImage.cgImage }
        guard cgImages.count == pages.count, !cgImages.isEmpty else {
            stage = .failed(message: DocumentScannerService.ScannerError.noPages.localizedDescription)
            return
        }
        let currentEnhancement = enhancement

        do {
            let (outputURL, byteCount) = try await Task.detached(priority: .userInitiated) {
                let data = try DocumentScannerService.createPDF(from: cgImages, enhancement: currentEnhancement)
                let url = try OutputFiles.write(data, name: baseName, ext: "pdf")
                return (url, data.count)
            }.value

            // Use the name actually written (it gets " (2)" added if the name was taken).
            stage = .result(fileURL: outputURL, filename: outputURL.lastPathComponent, byteCount: byteCount)
        } catch {
            stage = .failed(message: error.localizedDescription)
        }
    }

    /// Persists the generated PDF's metadata so it shows up on the
    /// Files tab and in Recent Activity. The binary already lives in
    /// the sandbox from `createPDF()` — this only records the reference.
    /// Saves explicitly: relying on SwiftData's autosave here is risky
    /// because the sheet is dismissed immediately after this call, and
    /// autosave isn't guaranteed to have run before the context tears down.
    @discardableResult
    func recordResult(fileURL: URL, filename: String, byteCount: Int, in context: ModelContext) -> Bool {
        let relativePath = fileURL.lastPathComponent
        let file = ProcessedFile(filename: filename, kind: .pdf, byteSize: byteCount, relativePath: relativePath)
        context.insert(file)
        context.insert(RecentItem(toolID: .scanDocument, summary: "Document scanned", relativePath: relativePath, fileID: file.id))
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }

    static func defaultName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        return "Scan \(formatter.string(from: .now))"
    }

    private static func sanitized(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = trimmed.components(separatedBy: invalidCharacters).joined(separator: "-")
        return cleaned.isEmpty ? defaultName() : cleaned
    }
}

import Foundation
import SwiftUI
import Observation
import SwiftData

@MainActor
@Observable
final class PDFCompressorViewModel {
    enum Stage: Equatable {
        case pickFile
        case configure
        case processing
        case result(fileURL: URL, filename: String, originalBytes: Int, compressedBytes: Int)
        case failed(message: String)
    }

    var stage: Stage = .pickFile
    var isFileImporterPresented = false
    var sourceURL: URL?
    nonisolated(unsafe) private var stagedTempURL: URL?
    var originalBytes: Int = 0
    var mode: CompressionMode = .quality(AppPreferences.defaultPDFCompression)
    var customTargetMB: Double = 2.0
    var outputName: String = ""

    func cleanupStagedFile() {
        if let stagedTempURL {
            try? FileManager.default.removeItem(at: stagedTempURL)
            self.stagedTempURL = nil
        }
    }

    deinit {
        if let stagedTempURL {
            try? FileManager.default.removeItem(at: stagedTempURL)
        }
    }

    func handlePickedFile(_ url: URL) {
        // Security-scoped access is required for files picked via
        // the document picker outside the app's own sandbox.
        guard url.startAccessingSecurityScopedResource() else {
            stage = .failed(message: "Couldn't access that file.")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        cleanupStagedFile()

        // Copy into a temp location so we still have access after
        // the security scope above ends.
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("pdf-compressor", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let temp = tempDir.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
        do {
            try FileManager.default.copyItem(at: url, to: temp)
        } catch {
            stage = .failed(message: "Couldn't read that file.")
            return
        }

        stagedTempURL = temp
        sourceURL = temp
        originalBytes = PDFCompressionService.fileSize(at: temp)
        outputName = "Compressed \(url.deletingPathExtension().lastPathComponent)"
        stage = .configure
    }

    /// Starts from a file imported on Home (already in our temp folder).
    func preload(_ url: URL) {
        sourceURL = url
        originalBytes = PDFCompressionService.fileSize(at: url)
        outputName = "Compressed \(url.deletingPathExtension().lastPathComponent)"
        stage = .configure
    }

    @MainActor
    func compress(in context: ModelContext) async {
        guard let sourceURL else { return }
        stage = .processing
        do {
            let data: Data
            switch mode {
            case .quality(let quality):
                data = try await PDFCompressionService.compress(url: sourceURL, quality: quality)
            case .targetSize(let target):
                data = try await PDFCompressionService.compress(url: sourceURL, target: target)
            }

            let baseName = Self.sanitized(outputName)
            let outputURL = try await Task.detached(priority: .userInitiated) {
                try OutputFiles.write(data, name: baseName, ext: "pdf")
            }.value
            cleanupStagedFile()
            // Use the name actually written (it gets " (2)" added if the name was taken).
            stage = .result(fileURL: outputURL, filename: outputURL.lastPathComponent,
                            originalBytes: originalBytes, compressedBytes: data.count)
        } catch {
            stage = .failed(message: error.localizedDescription)
        }
    }

    /// Saves explicitly rather than relying on autosave, since the
    /// sheet dismisses right after this call.
    @discardableResult
    func recordResult(filename: String, byteCount: Int, in context: ModelContext) -> Bool {
        cleanupStagedFile()
        let file = ProcessedFile(filename: filename, kind: .pdf, byteSize: byteCount, relativePath: filename)
        context.insert(file)
        context.insert(RecentItem(toolID: .compressPDF, summary: "PDF compressed", relativePath: filename, fileID: file.id))
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }

    var effectiveTarget: TargetSize {
        if case .targetSize(let target) = mode { return target }
        return .custom(Int(customTargetMB * 1_000_000))
    }

    private static func sanitized(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = trimmed.components(separatedBy: invalidCharacters).joined(separator: "-")
        return cleaned.isEmpty ? "Compressed" : cleaned
    }
}

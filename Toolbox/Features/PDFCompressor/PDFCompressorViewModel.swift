import Foundation
import SwiftUI
import Observation
import SwiftData

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
    var originalBytes: Int = 0
    var mode: CompressionMode = .quality(AppPreferences.defaultPDFCompression)
    var customTargetMB: Double = 2.0
    var outputName: String = ""

    func handlePickedFile(_ url: URL) {
        // Security-scoped access is required for files picked via
        // the document picker outside the app's own sandbox.
        guard url.startAccessingSecurityScopedResource() else {
            stage = .failed(message: "Couldn't access that file.")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // Copy into a temp location so we still have access after
        // the security scope above ends.
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: temp)
        do {
            try FileManager.default.copyItem(at: url, to: temp)
        } catch {
            stage = .failed(message: "Couldn't read that file.")
            return
        }

        sourceURL = temp
        originalBytes = PDFCompressionService.fileSize(at: temp)
        outputName = "Compressed \(temp.deletingPathExtension().lastPathComponent)"
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

            let requestedName = "\(Self.sanitized(outputName)).pdf"
            let outputURL = try Self.write(data, filename: requestedName)
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
        context.insert(ProcessedFile(filename: filename, kind: .pdf, byteSize: byteCount, relativePath: filename))
        context.insert(RecentItem(toolID: .compressPDF, summary: "PDF compressed"))
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

    /// Writes to the sandbox Documents directory, uniquing the name
    /// instead of silently overwriting an existing file.
    private static func write(_ data: Data, filename: String) throws -> URL {
        let directory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: true)
        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var candidate = directory.appendingPathComponent(filename)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base) (\(counter)).\(ext)")
            counter += 1
        }
        try data.write(to: candidate, options: .atomic)
        return candidate
    }
}

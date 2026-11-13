import Foundation
import SwiftUI
import PhotosUI
import AVFoundation
import VisionKit
import Observation
import SwiftData

@MainActor
@Observable
final class OCRViewModel {
    enum Stage: Equatable {
        case pick
        case processing(done: Int, total: Int)
        case result
        case failed(message: String)
    }

    var stage: Stage = .pick
    /// Editable: the user can fix recognition mistakes before exporting.
    var text = ""
    var fileName = OCRViewModel.defaultName()

    var isCameraPresented = false
    var isPhotoPickerPresented = false
    var photoSelection: [PhotosPickerItem] = []

    var statusMessage: String?
    var alertMessage: String?

    private var task: Task<Void, Never>?

    var progress: Double? {
        if case .processing(let done, let total) = stage, total > 1 { return Double(done) / Double(total) }
        return nil
    }

    var wordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    // MARK: - Input

    func openCamera() {
        guard VNDocumentCameraViewController.isSupported else {
            alertMessage = "Camera scanning isn't available on this device. You can choose a photo instead."
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            alertMessage = "Camera access is off. Turn it on in Settings › Toolbox › Camera, or choose a photo instead."
        default:
            isCameraPresented = true
        }
    }

    func processCameraPages(_ images: [UIImage]) {
        isCameraPresented = false
        let inputs = images.compactMap(OCRService.input(from:))
        guard !inputs.isEmpty else {
            stage = .failed(message: "The scanned pages couldn't be read.")
            return
        }
        run(inputs, cleanup: [])
    }

    func processPhotos() async {
        let items = photoSelection
        photoSelection = []
        guard !items.isEmpty else { return }

        stage = .processing(done: 0, total: items.count)
        var inputs: [OCRInput] = []
        var urls: [URL] = []
        for item in items {
            guard let file = try? await item.loadTransferable(type: PickedImageFile.self) else { continue }
            urls.append(file.url)
            inputs.append(.file(file.url))
        }
        guard !inputs.isEmpty else {
            stage = .failed(message: "None of the selected photos could be opened. They may be stored in iCloud and unavailable right now.")
            return
        }
        run(inputs, cleanup: urls)
    }

    /// Starts from a file imported on Home (already in our temp folder).
    func processImported(_ media: ImportedMedia) {
        let inputs: [OCRInput]
        switch media.kind {
        case .image: inputs = media.items.map { .file($0.url) }
        case .pdf: inputs = media.items.first.map { OCRService.pdfInputs(at: $0.url) } ?? []
        }
        guard !inputs.isEmpty else {
            stage = .failed(message: "That file couldn't be opened.")
            return
        }
        run(inputs, cleanup: media.items.map(\.url))
    }

    // MARK: - Recognition

    private func run(_ inputs: [OCRInput], cleanup: [URL]) {
        stage = .processing(done: 0, total: inputs.count)
        task = Task {
            defer { cleanup.forEach { try? FileManager.default.removeItem(at: $0) } }
            var pieces: [String] = []
            do {
                for (index, input) in inputs.enumerated() {
                    try Task.checkCancellation()
                    let piece = try await Task.detached(priority: .userInitiated) {
                        try OCRService.recognize(input)
                    }.value
                    if !piece.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { pieces.append(piece) }
                    stage = .processing(done: index + 1, total: inputs.count)
                }
                try Task.checkCancellation()

                guard !pieces.isEmpty else {
                    stage = .failed(message: "No text was found. Try a sharper photo with good lighting, and keep the text flat and in frame.")
                    return
                }
                text = pieces.joined(separator: "\n\n")
                fileName = Self.defaultName()
                statusMessage = nil
                stage = .result
            } catch is CancellationError {
                stage = .pick
            } catch {
                stage = .failed(message: "Something went wrong while reading the text. Please try again.")
            }
        }
    }

    func cancel() { task?.cancel() }

    func scanAnother() {
        text = ""
        statusMessage = nil
        fileName = Self.defaultName()
        stage = .pick
    }

    // MARK: - Export

    func exportTXT(in context: ModelContext) {
        guard let data = text.data(using: .utf8) else { return }
        export(data, ext: "txt", kind: .text, in: context)
    }

    func exportPDF(in context: ModelContext) {
        export(OCRService.makePDF(from: text), ext: "pdf", kind: .pdf, in: context)
    }

    private func export(_ data: Data, ext: String, kind: ProcessedFileKind, in context: ModelContext) {
        do {
            let url = try OutputFiles.write(data, name: Self.sanitized(fileName), ext: ext)
            context.insert(ProcessedFile(filename: url.lastPathComponent, kind: kind,
                                         byteSize: data.count, relativePath: url.lastPathComponent))
            try? context.save()
            statusMessage = "Saved \(url.lastPathComponent). It's also in your Files tab."
            ShareSheet.present([url])
        } catch {
            let nsError = error as NSError
            alertMessage = (nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError)
                ? "There isn't enough free storage on your iPhone to save this file."
                : "Couldn't save the file. Please try again."
        }
    }

    // MARK: - Names

    static func defaultName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        return "Extracted Text \(formatter.string(from: .now))"
    }

    private static func sanitized(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = trimmed.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.isEmpty ? defaultName() : cleaned
    }
}

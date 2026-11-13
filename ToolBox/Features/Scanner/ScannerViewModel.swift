import UIKit
import SwiftUI
import Observation
import SwiftData

@Observable
final class ScannerViewModel {
    enum Stage: Equatable {
        case review
        case processing
        case result(fileURL: URL, filename: String, byteCount: Int)
        case failed(message: String)
    }

    var pages: [ScannedPage] = []
    var enhancement: PageEnhancement = .color
    var documentName: String = ScannerViewModel.defaultName()
    var stage: Stage = .review
    var isCameraPresented = false

    var hasPages: Bool { !pages.isEmpty }

    func addPages(_ images: [UIImage]) {
        pages.append(contentsOf: images.map { ScannedPage(originalImage: $0) })
        isCameraPresented = false
    }

    func cancelCamera() {
        isCameraPresented = false
    }

    func deletePages(at offsets: IndexSet) {
        pages.remove(atOffsets: offsets)
    }

    func movePages(from source: IndexSet, to destination: Int) {
        pages.move(fromOffsets: source, toOffset: destination)
    }

    /// Removes a page and immediately reopens the camera so the user
    /// can recapture it — the spec's "Retake" action.
    func retake(_ page: ScannedPage) {
        pages.removeAll { $0.id == page.id }
        isCameraPresented = true
    }

    @MainActor
    func createPDF() async {
        stage = .processing
        do {
            let data = try await DocumentScannerService.createPDF(from: pages, enhancement: enhancement)
            let requestedName = "\(Self.sanitized(documentName)).pdf"
            let url = try Self.write(data, filename: requestedName)
            // Use the name actually written (it gets " (2)" added if the name was taken).
            stage = .result(fileURL: url, filename: url.lastPathComponent, byteCount: data.count)
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
        context.insert(ProcessedFile(filename: filename, kind: .pdf, byteSize: byteCount, relativePath: relativePath))
        context.insert(RecentItem(toolID: .scanDocument, summary: "Document scanned"))
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

    /// Writes to the sandbox Documents directory, uniquing the name
    /// (" (2)", " (3)", ...) instead of silently overwriting an
    /// existing file with the same name.
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

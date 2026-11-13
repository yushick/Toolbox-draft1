import Foundation
import UniformTypeIdentifiers
import UIKit
import PDFKit
import SwiftUI

enum ImportKind: Sendable { case pdf, image }

/// One imported file, already copied into the app's temp folder so it
/// stays readable after the picker / drop session ends.
struct ImportedItem: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    /// Original file name without extension.
    let name: String
}

/// A batch the user imported on Home. Always a single kind: either one
/// PDF, or one or more images.
struct ImportedMedia: Identifiable, Sendable {
    let id = UUID()
    let kind: ImportKind
    let items: [ImportedItem]
    /// Files that were dropped alongside but can't be used here.
    let skipped: Int
}

/// An operation offered for an imported batch.
struct ImportAction: Identifiable {
    let tool: Tool
    let title: String
    let subtitle: String
    let icon: String
    var id: ToolID { tool.id }
}

/// Transferable used by drag & drop: copies whatever is dropped into
/// our own temp folder.
struct DroppedFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .item) { received in
            DroppedFile(url: try ImportService.copyIn(received.file))
        }
    }
}

enum ImportService {

    private static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("imports", isDirectory: true)
    }

    // MARK: - Staging

    /// Copies a file into `imports/<uuid>/<original name>`, so names stay
    /// clean and two files with the same name never collide.
    static func copyIn(_ source: URL) throws -> URL {
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    /// Files chosen with the document picker need security-scoped access.
    static func stagePicked(_ urls: [URL]) -> [ImportedItem] {
        urls.compactMap { url in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let copy = try? copyIn(url) else { return nil }
            return item(for: copy)
        }
    }

    static func item(for url: URL) -> ImportedItem {
        ImportedItem(url: url, name: url.deletingPathExtension().lastPathComponent)
    }

    // MARK: - Classifying

    static func kind(of url: URL) -> ImportKind? {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return nil }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .image) { return .image }
        return nil
    }

    /// Turns a mixed batch into one usable batch. Images win if there are
    /// any (every image tool takes several); otherwise the first PDF.
    /// Returns nil when nothing in the batch is supported.
    static func makeMedia(from items: [ImportedItem]) -> ImportedMedia? {
        let images = items.filter { kind(of: $0.url) == .image }
        let pdfs = items.filter { kind(of: $0.url) == .pdf }

        if !images.isEmpty {
            return ImportedMedia(kind: .image, items: images, skipped: items.count - images.count)
        }
        if let first = pdfs.first {
            return ImportedMedia(kind: .pdf, items: [first], skipped: items.count - 1)
        }
        return nil
    }

    /// Deletes the temp copies (used when the user backs out).
    static func discard(_ media: ImportedMedia) {
        for item in media.items {
            try? FileManager.default.removeItem(at: item.url.deletingLastPathComponent())
        }
    }

    // MARK: - Offered actions

    static func actions(for media: ImportedMedia) -> [ImportAction] {
        func tool(_ id: ToolID) -> Tool { Tool.all.first { $0.id == id }! }
        let many = media.items.count > 1

        switch media.kind {
        case .pdf:
            return [
                ImportAction(tool: tool(.compressPDF), title: "Compress PDF",
                             subtitle: "Make the file smaller", icon: "doc.badge.arrow.up"),
                ImportAction(tool: tool(.ocr), title: "Extract Text",
                             subtitle: "Copy the text out of this PDF", icon: "text.viewfinder")
            ]
        case .image:
            var list = [
                ImportAction(tool: tool(.compressImage), title: "Compress",
                             subtitle: many ? "Shrink these photos" : "Reduce the file size",
                             icon: "photo.badge.arrow.down"),
                ImportAction(tool: tool(.resizeImage), title: "Resize",
                             subtitle: "Social presets or custom size",
                             icon: "arrow.up.left.and.arrow.down.right"),
                ImportAction(tool: tool(.ocr), title: "Extract Text",
                             subtitle: "Read the text in \(many ? "these photos" : "this photo")",
                             icon: "text.viewfinder")
            ]
            if !many {
                list.append(ImportAction(tool: tool(.qrBarcodeScanner), title: "Scan QR / Barcode",
                                         subtitle: "Read a code in this photo", icon: "qrcode.viewfinder"))
            }
            return list
        }
    }

    // MARK: - Summary

    static func summary(for media: ImportedMedia) -> (title: String, detail: String) {
        let bytes = media.items.reduce(0) {
            $0 + ((try? $1.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        let size = bytes.formattedBytes
        switch media.kind {
        case .pdf:
            let pages = PDFDocument(url: media.items[0].url)?.pageCount ?? 0
            let pageText = pages > 0 ? "\(pages) page\(pages == 1 ? "" : "s") · " : ""
            return (media.items[0].name, pageText + size)
        case .image:
            if media.items.count == 1 { return (media.items[0].name, size) }
            return ("\(media.items.count) photos", size)
        }
    }

    static func previewImage(for media: ImportedMedia) -> UIImage? {
        guard let first = media.items.first else { return nil }
        switch media.kind {
        case .image:
            return ImageProcessingService.thumbnail(url: first.url, maxPixelSize: 240)
        case .pdf:
            return PDFDocument(url: first.url)?.page(at: 0)?.thumbnail(of: CGSize(width: 120, height: 160), for: .cropBox)
        }
    }
}

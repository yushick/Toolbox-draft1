import Foundation
import SwiftData

/// A lightweight, local-only record of recent activity
/// ("PDF compressed 2 minutes ago"). No analytics, no network.
@Model
final class RecentItem {
    var id: UUID
    var toolID: String
    var summary: String        // e.g. "PDF compressed"
    var timestamp: Date
    var relativePath: String?
    var fileID: UUID?

    init(toolID: ToolID, summary: String, timestamp: Date = .now,
         relativePath: String? = nil, fileID: UUID? = nil) {
        self.id = UUID()
        self.toolID = toolID.rawValue
        self.summary = summary
        self.timestamp = timestamp
        self.relativePath = relativePath
        self.fileID = fileID
    }
}

extension RecentItem {
    /// True if the item is not file-backed (like a QR scan or in-memory OCR)
    /// or if its referenced file actually exists on disk.
    var isFileAvailable: Bool {
        if let relativePath, !relativePath.isEmpty {
            return FileService.exists(relativePath: relativePath)
        }

        // File-producing tools with no relativePath (e.g. legacy rows) cannot be
        // located on disk and should be treated as unavailable / purged.
        let isFileProducingTool: Bool = {
            if let id = ToolID(rawValue: toolID) {
                switch id {
                case .scanDocument, .compressPDF, .compressImage, .resizeImage:
                    return true
                case .qrBarcodeScanner, .ocr:
                    return false
                }
            }
            return toolID == "documentScanner" || toolID == "pdfCompressor" ||
                   toolID == "imageCompressor" || toolID == "imageResizer"
        }()

        if isFileProducingTool {
            return false
        }

        if summary.hasPrefix("Saved ") {
            let candidate = String(summary.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty && candidate.contains(".") {
                return FileService.exists(relativePath: candidate)
            }
        }
        return true
    }
}

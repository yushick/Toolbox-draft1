import Foundation

/// The single source of truth for every tool shown on Home and in Search.
/// Home and Search both render from `Tool.all` rather than duplicating
/// tool definitions in multiple places.
enum ToolCategory: String, CaseIterable {
    case documents = "Documents"
    case images = "Images"
    case scan = "Scan"
}

enum ToolID: String, Codable {
    case scanDocument
    case compressPDF
    case compressImage
    case resizeImage
    case qrBarcodeScanner
    case ocr
}

struct Tool: Identifiable, Hashable {
    let id: ToolID
    let title: String
    let subtitle: String
    /// SF Symbol name — never an emoji.
    let icon: String
    let category: ToolCategory
    /// Larger, "hero" placement on Home (Scan Document / Compress PDF).
    let isPrimary: Bool

    static let all: [Tool] = [
        Tool(id: .scanDocument, title: "Scan Document", subtitle: "Turn paper into a PDF",
             icon: "doc.viewfinder", category: .documents, isPrimary: true),
        Tool(id: .compressPDF, title: "Compress PDF", subtitle: "Shrink PDF file size",
             icon: "doc.badge.arrow.up", category: .documents, isPrimary: true),
        Tool(id: .compressImage, title: "Compress Image", subtitle: "Reduce photo file size",
             icon: "photo.badge.arrow.down", category: .images, isPrimary: false),
        Tool(id: .resizeImage, title: "Resize Image", subtitle: "Fit any dimensions",
             icon: "arrow.up.left.and.arrow.down.right", category: .images, isPrimary: false),
        Tool(id: .qrBarcodeScanner, title: "QR & Barcode", subtitle: "Scan any code instantly",
             icon: "qrcode.viewfinder", category: .scan, isPrimary: false),
        Tool(id: .ocr, title: "OCR", subtitle: "Extract text from images",
             icon: "text.viewfinder", category: .scan, isPrimary: false),
    ]

    /// Simple, fast, on-device search across title/subtitle/category —
    /// no backend, matches the app's privacy-first design.
    static func search(_ query: String) -> [Tool] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return all.filter {
            $0.title.lowercased().contains(q) ||
            $0.subtitle.lowercased().contains(q) ||
            $0.category.rawValue.lowercased().contains(q)
        }
    }
}

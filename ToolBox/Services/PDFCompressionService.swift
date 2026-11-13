import UIKit
import PDFKit

/// Real PDF compression: each page is rasterized at a controlled
/// resolution and re-encoded as JPEG, then reassembled into a new
/// PDF. This genuinely reduces file size for image-heavy/scanned
/// PDFs (the common case for a document-utility app) — per the
/// spec's rule against fake compression, output is always measured,
/// never invented.
///
/// Trade-off worth knowing: because pages are rasterized, embedded
/// selectable text becomes part of the image and is no longer
/// selectable/searchable in the compressed output. That's an
/// inherent trade-off of image-based PDF compression, not a bug —
/// vector/text-preserving compression would need a different
/// approach (font subsetting, stream recompression) that's a
/// reasonable Stage 3.1 follow-up if it turns out to matter.
enum PDFCompressionService {

    enum CompressionError: LocalizedError {
        case cannotOpen
        case noPages
        case couldNotReachTarget

        var errorDescription: String? {
            switch self {
            case .cannotOpen: return "This PDF couldn't be opened."
            case .noPages: return "This PDF has no pages to compress."
            case .couldNotReachTarget: return "Couldn't compress below that target without heavy quality loss."
            }
        }
    }

    static func fileSize(at url: URL) -> Int {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
    }

    /// Compress using a fixed quality/resolution preset.
    static func compress(url: URL, quality: CompressionQuality) async throws -> Data {
        let (jpegQuality, maxDimension) = quality.settings
        return try await render(url: url, jpegQuality: jpegQuality, maxDimension: maxDimension)
    }

    /// Compress toward an explicit target size, stepping quality down
    /// until the result fits (bounded search — never loops forever).
    static func compress(url: URL, target: TargetSize) async throws -> Data {
        var quality: CGFloat = 0.8
        var dimension: CGFloat = 1800
        var lastData: Data?

        for _ in 0..<6 {
            let data = try await render(url: url, jpegQuality: quality, maxDimension: dimension)
            lastData = data
            if data.count <= target.bytes { return data }
            quality = max(0.2, quality - 0.15)
            dimension = max(700, dimension - 250)
        }

        // Return the smallest attempt even if the target was tight —
        // reported honestly to the user rather than pretending success.
        guard let lastData else { throw CompressionError.couldNotReachTarget }
        return lastData
    }

    private static func render(url: URL, jpegQuality: CGFloat, maxDimension: CGFloat) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            guard let document = PDFDocument(url: url) else { throw CompressionError.cannotOpen }
            guard document.pageCount > 0 else { throw CompressionError.noPages }

            let outputData = NSMutableData()
            UIGraphicsBeginPDFContextToData(outputData, .zero, nil)
            defer { UIGraphicsEndPDFContext() }

            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let pageBounds = page.bounds(for: .mediaBox)
                let aspect = pageBounds.height > 0 ? pageBounds.width / pageBounds.height : 1
                let renderSize: CGSize = aspect >= 1
                    ? CGSize(width: maxDimension, height: maxDimension / aspect)
                    : CGSize(width: maxDimension * aspect, height: maxDimension)

                let renderer = UIGraphicsImageRenderer(size: renderSize)
                let pageImage = renderer.image { context in
                    UIColor.white.setFill()
                    context.fill(CGRect(origin: .zero, size: renderSize))
                    context.cgContext.translateBy(x: 0, y: renderSize.height)
                    context.cgContext.scaleBy(x: renderSize.width / pageBounds.width,
                                               y: -renderSize.height / pageBounds.height)
                    page.draw(with: .mediaBox, to: context.cgContext)
                }

                guard let jpegData = pageImage.jpegData(compressionQuality: jpegQuality),
                      let recompressed = UIImage(data: jpegData) else { continue }

                UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)
                recompressed.draw(in: pageBounds)
            }

            return outputData as Data
        }.value
    }
}

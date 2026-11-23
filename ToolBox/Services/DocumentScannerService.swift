import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import PDFKit

/// Real (non-simulated) image enhancement and PDF assembly for the
/// Document Scanner. All work happens off the main actor so large
/// multi-page scans never freeze the UI (see spec §24, Performance).
enum DocumentScannerService {

    private static let ciContext = CIContext()

    /// Applies the selected enhancement to a captured page CGImage.
    nonisolated static func enhance(_ cgImage: CGImage, mode: PageEnhancement) -> CGImage {
        guard mode != .color else { return cgImage }
        let ciImage = CIImage(cgImage: cgImage)
        let output: CIImage

        switch mode {
        case .color:
            return cgImage

        case .grayscale:
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.saturation = 0
            filter.contrast = 1.05
            output = filter.outputImage ?? ciImage

        case .blackAndWhite:
            // Desaturate, boost contrast, then threshold toward pure
            // black/white so it reads like a scanned document rather
            // than a flat gray photo.
            let mono = CIFilter.colorControls()
            mono.inputImage = ciImage
            mono.saturation = 0
            mono.contrast = 1.6
            let contrasted = mono.outputImage ?? ciImage

            let threshold = CIFilter.colorPosterize()
            threshold.inputImage = contrasted
            threshold.levels = 2
            output = threshold.outputImage ?? contrasted
        }

        guard let rendered = ciContext.createCGImage(output, from: output.extent) else { return cgImage }
        return rendered
    }

    /// Convenience for enhancing a UIImage using its underlying CGImage.
    nonisolated static func enhance(_ image: UIImage, mode: PageEnhancement) -> UIImage {
        guard mode != .color, let cgImage = image.cgImage else { return image }
        let rendered = enhance(cgImage, mode: mode)
        return UIImage(cgImage: rendered, scale: image.scale, orientation: image.imageOrientation)
    }

    enum ScannerError: LocalizedError {
        case noPages
        case renderingFailed

        var errorDescription: String? {
            switch self {
            case .noPages: return "There are no pages to save."
            case .renderingFailed: return "Something went wrong while processing your document."
            }
        }
    }

    /// Builds a real, valid PDF from enhanced page images. Nonisolated and operates on Sendable CGImages.
    nonisolated static func createPDF(from images: [CGImage], enhancement: PageEnhancement) throws -> Data {
        guard !images.isEmpty else { throw ScannerError.noPages }

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)

        for cgImage in images {
            let enhanced = enhance(cgImage, mode: enhancement)

            // A4 at 72dpi, scaled to the image's aspect ratio so
            // portrait/landscape captures both render correctly.
            let maxWidth: CGFloat = 595
            let maxHeight: CGFloat = 842
            let imageSize = CGSize(width: enhanced.width, height: enhanced.height)
            let scale = min(maxWidth / imageSize.width, maxHeight / imageSize.height)
            let pageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

            UIGraphicsBeginPDFPageWithInfo(CGRect(origin: .zero, size: pageSize), nil)
            UIImage(cgImage: enhanced).draw(in: CGRect(origin: .zero, size: pageSize))
        }

        UIGraphicsEndPDFContext()
        return pdfData as Data
    }

    /// Backwards-compatible overload for [ScannedPage] extracting CGImages.
    nonisolated static func createPDF(from pages: [ScannedPage], enhancement: PageEnhancement) async throws -> Data {
        let images = pages.compactMap { $0.originalImage.cgImage }
        guard images.count == pages.count else { throw ScannerError.renderingFailed }
        return try createPDF(from: images, enhancement: enhancement)
    }
}

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import PDFKit

/// Real (non-simulated) image enhancement and PDF assembly for the
/// Document Scanner. All work happens off the main actor so large
/// multi-page scans never freeze the UI (see spec §24, Performance).
enum DocumentScannerService {

    private static let ciContext = CIContext()

    /// Applies the selected enhancement to a captured page. Runs on a
    /// background thread; call from a Task, never directly on the
    /// main actor for large images.
    static func enhance(_ image: UIImage, mode: PageEnhancement) -> UIImage {
        guard mode != .color, let cgImage = image.cgImage else { return image }
        let ciImage = CIImage(cgImage: cgImage)
        let output: CIImage

        switch mode {
        case .color:
            return image

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

        guard let rendered = ciContext.createCGImage(output, from: output.extent) else { return image }
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

    /// Builds a real, valid PDF from enhanced page images — one page
    /// per image, sized to the image's own aspect ratio at print
    /// resolution, matching Files.app / Notes-style document scans.
    static func createPDF(from pages: [ScannedPage], enhancement: PageEnhancement) async throws -> Data {
        guard !pages.isEmpty else { throw ScannerError.noPages }

        return try await Task.detached(priority: .userInitiated) {
            let pdfData = NSMutableData()
            UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)
            defer { UIGraphicsEndPDFContext() }

            for page in pages {
                let enhanced = enhance(page.originalImage, mode: enhancement)
                guard let cgImage = enhanced.cgImage else { throw ScannerError.renderingFailed }

                // A4 at 72dpi, scaled to the image's aspect ratio so
                // portrait/landscape captures both render correctly.
                let maxWidth: CGFloat = 595
                let maxHeight: CGFloat = 842
                let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
                let scale = min(maxWidth / imageSize.width, maxHeight / imageSize.height)
                let pageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

                UIGraphicsBeginPDFPageWithInfo(CGRect(origin: .zero, size: pageSize), nil)
                enhanced.draw(in: CGRect(origin: .zero, size: pageSize))
            }

            return pdfData as Data
        }.value
    }
}

import Foundation
import Vision
import UIKit
import CoreText

/// What to read text from. Photos arrive as temp files; camera pages
/// arrive as images.
enum OCRInput: @unchecked Sendable {
    case file(URL)
    case image(CGImage, CGImagePropertyOrientation)
}

/// On-device text recognition (Vision) and text-to-PDF export.
/// Nothing here touches the network.
enum OCRService {

    /// Hindi is only available on iOS versions whose Vision framework ships
    /// a Hindi model, so this is checked at runtime rather than assumed.
    static var supportsHindi: Bool {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let languages = (try? request.supportedRecognitionLanguages()) ?? []
        return languages.contains { $0.lowercased().hasPrefix("hi") }
    }

    static func input(from image: UIImage) -> OCRInput? {
        guard let cgImage = image.cgImage else { return nil }
        return .image(cgImage, orientation(for: image.imageOrientation))
    }

    /// Explicit mapping, so it doesn't depend on a convenience initializer
    /// that isn't available in every SDK.
    private static func orientation(for orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    /// Returns the recognised text, one line per line of text found
    /// (empty if nothing was found).
    static func recognize(_ input: OCRInput) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        let handler: VNImageRequestHandler
        switch input {
        case .file(let url):
            handler = VNImageRequestHandler(url: url, options: [:])
        case .image(let cgImage, let orientation):
            handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        }
        try handler.perform([request])

        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: "\n")
    }

    /// Lays text out on A4 pages, flowing onto as many pages as needed.
    static func makePDF(from text: String) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 48

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        let attributed = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ])

        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let textRect = CGRect(x: margin, y: margin,
                              width: pageRect.width - margin * 2, height: pageRect.height - margin * 2)
        let path = CGPath(rect: textRect, transform: nil)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            var location = 0
            let length = attributed.length
            repeat {
                context.beginPage()
                let cg = context.cgContext
                cg.saveGState()
                // Core Text draws bottom-up, the PDF context is top-down.
                cg.textMatrix = .identity
                cg.translateBy(x: 0, y: pageRect.height)
                cg.scaleBy(x: 1, y: -1)

                let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), path, nil)
                CTFrameDraw(frame, cg)
                let visible = CTFrameGetVisibleStringRange(frame)
                cg.restoreGState()

                if visible.length == 0 { break }   // never loop forever
                location = visible.location + visible.length
            } while location < length
        }
    }
}

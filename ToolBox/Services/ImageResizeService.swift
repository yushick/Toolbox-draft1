import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Real resizing with ImageIO + Core Graphics. The source is decoded
/// straight to the size it's needed at, so large photos are never
/// fully loaded into memory.
enum ImageResizeService {

    enum ResizeError: LocalizedError {
        case cannotRead
        case cannotEncode

        var errorDescription: String? {
            switch self {
            case .cannotRead: return "One of the images couldn't be read."
            case .cannotEncode: return "One of the images couldn't be saved after resizing."
            }
        }
    }

    /// Pixel size as the user sees it (EXIF rotation applied).
    static func orientedPixelSize(of url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { return nil }
        let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
        return (5...8).contains(orientation)
            ? CGSize(width: height, height: width)
            : CGSize(width: width, height: height)
    }

    /// Pure calculation, shared by the live preview and the real resize.
    /// Fit never enlarges; Fill returns exactly the target.
    static func outputSize(source: CGSize, target: CGSize, mode: ResizeMode) -> CGSize {
        let targetW = max(1, target.width.rounded())
        let targetH = max(1, target.height.rounded())
        switch mode {
        case .fill:
            return CGSize(width: targetW, height: targetH)
        case .fit:
            guard source.width > 0, source.height > 0 else { return CGSize(width: targetW, height: targetH) }
            let scale = min(targetW / source.width, targetH / source.height, 1)
            return CGSize(width: max(1, (source.width * scale).rounded()),
                          height: max(1, (source.height * scale).rounded()))
        }
    }

    static func resize(sourceURL: URL, target: CGSize, mode: ResizeMode,
                       format: ImageOutputFormat, quality: Double) throws -> (data: Data, size: CGSize) {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let sourceSize = orientedPixelSize(of: sourceURL) else { throw ResizeError.cannotRead }

        let out = outputSize(source: sourceSize, target: target, mode: mode)
        let scale = mode == .fit
            ? out.width / sourceSize.width
            : max(out.width / sourceSize.width, out.height / sourceSize.height)

        // Decode only as large as needed. Enlarging happens at draw time.
        let decodeScale = min(scale, 1)
        let maxPixel = max(1, Int((max(sourceSize.width, sourceSize.height) * decodeScale).rounded(.up)))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ResizeError.cannotRead
        }

        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = 1
        rendererFormat.opaque = true
        let renderer = UIGraphicsImageRenderer(size: out, format: rendererFormat)
        let rendered = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: out))
            let drawRect: CGRect
            if mode == .fit {
                drawRect = CGRect(origin: .zero, size: out)
            } else {
                let drawW = sourceSize.width * scale
                let drawH = sourceSize.height * scale
                drawRect = CGRect(x: (out.width - drawW) / 2, y: (out.height - drawH) / 2,
                                  width: drawW, height: drawH)
            }
            UIImage(cgImage: decoded).draw(in: drawRect)
        }

        guard let cgImage = rendered.cgImage else { throw ResizeError.cannotEncode }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, format.utType.identifier as CFString, 1, nil) else {
            throw ResizeError.cannotEncode
        }
        CGImageDestinationAddImage(destination, cgImage,
                                   [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ResizeError.cannotEncode }
        return (data as Data, out)
    }
}

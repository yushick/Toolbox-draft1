import Foundation
import ImageIO
import UniformTypeIdentifiers
import UIKit

enum ImageOutputFormat: String, CaseIterable, Identifiable, Sendable {
    case jpeg = "JPEG"
    case heic = "HEIC"

    var id: String { rawValue }
    var utType: UTType { self == .jpeg ? .jpeg : .heic }
    var fileExtension: String { self == .jpeg ? "jpg" : "heic" }

    /// HEIC encoding isn't available everywhere (e.g. some simulators),
    /// so the UI only offers formats the system can really write.
    var isSupported: Bool {
        let ids = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return ids.contains(utType.identifier)
    }
}

/// Longest-edge cap applied during compression. Aspect ratio is
/// always preserved, and images are never upscaled.
enum MaxDimension: Int, CaseIterable, Identifiable, Sendable {
    case original = 0
    case px4096 = 4096
    case px2048 = 2048
    case px1280 = 1280
    case px1080 = 1080

    var id: Int { rawValue }
    var label: String { self == .original ? "Original size" : "\(rawValue) px" }
    var pixels: Int? { self == .original ? nil : rawValue }
}

/// Real ImageIO-based compression. Images are decoded straight to the
/// target size (never fully loaded at original resolution), then
/// re-encoded at the chosen quality. Output size is measured, not guessed.
enum ImageProcessingService {

    enum ImageError: LocalizedError {
        case cannotRead
        case cannotEncode

        var errorDescription: String? {
            switch self {
            case .cannotRead: return "One of the images couldn't be read."
            case .cannotEncode: return "One of the images couldn't be compressed."
            }
        }
    }

    static func fileSize(at url: URL) -> Int {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
    }

    static func compress(sourceURL: URL, format: ImageOutputFormat,
                         quality: Double, maxPixelSize: Int?) throws -> Data {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else { throw ImageError.cannotRead }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let longest = max(width, height)
        guard longest > 0 else { throw ImageError.cannotRead }

        let target = min(maxPixelSize ?? longest, longest)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: target
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImageError.cannotRead
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, format.utType.identifier as CFString, 1, nil) else {
            throw ImageError.cannotEncode
        }
        CGImageDestinationAddImage(destination, image,
                                   [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ImageError.cannotEncode }
        return output as Data
    }

    static func thumbnail(url: URL, maxPixelSize: Int = 160) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

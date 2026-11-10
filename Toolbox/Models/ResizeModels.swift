import Foundation
import CoreGraphics

/// Fit keeps the whole image and shrinks it to sit inside the target box
/// (the output can be smaller than the box on one side, never cropped).
/// Fill produces exactly the target size and crops the overflow.
enum ResizeMode: String, CaseIterable, Identifiable, Sendable {
    case fit = "Fit"
    case fill = "Fill"

    var id: String { rawValue }
    var detail: String {
        switch self {
        case .fit: return "Keeps the whole image. Nothing is cropped."
        case .fill: return "Exact size. Edges are cropped to fit."
        }
    }
}

enum ResizePreset: String, CaseIterable, Identifiable, Sendable {
    case instagramPost
    case instagramPortrait
    case instagramStory
    case landscapeHD
    case whatsApp
    case email
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .instagramPost: return "Instagram Post"
        case .instagramPortrait: return "Instagram Portrait"
        case .instagramStory: return "Instagram Story"
        case .landscapeHD: return "Landscape HD"
        case .whatsApp: return "WhatsApp"
        case .email: return "Email"
        case .custom: return "Custom"
        }
    }

    /// nil for `.custom`, where the user supplies the size.
    var size: CGSize? {
        switch self {
        case .instagramPost: return CGSize(width: 1080, height: 1080)
        case .instagramPortrait: return CGSize(width: 1080, height: 1350)
        case .instagramStory: return CGSize(width: 1080, height: 1920)
        case .landscapeHD: return CGSize(width: 1920, height: 1080)
        case .whatsApp: return CGSize(width: 1600, height: 1600)
        case .email: return CGSize(width: 1024, height: 1024)
        case .custom: return nil
        }
    }

    /// SF Symbol shown on the chip when no logo image has been added.
    var symbolName: String {
        switch self {
        case .instagramPost: return "square"
        case .instagramPortrait: return "rectangle.portrait"
        case .instagramStory: return "rectangle.portrait.on.rectangle.portrait"
        case .landscapeHD: return "rectangle"
        case .whatsApp: return "message"
        case .email: return "envelope"
        case .custom: return "slider.horizontal.3"
        }
    }

    /// Optional image name in Assets.xcassets. If an image with this name
    /// exists it is shown instead of the SF Symbol; if not, the symbol is
    /// used, so nothing breaks while the assets are missing.
    var logoAssetName: String? {
        switch self {
        case .instagramPost, .instagramPortrait, .instagramStory: return "logo-instagram"
        case .whatsApp: return "logo-whatsapp"
        default: return nil
        }
    }

    /// Social formats want an exact frame; sharing formats just want
    /// "no bigger than this".
    var defaultMode: ResizeMode {
        switch self {
        case .whatsApp, .email, .custom: return .fit
        default: return .fill
        }
    }

    var subtitle: String {
        switch self {
        case .whatsApp: return "Up to 1600 px"
        case .email: return "Up to 1024 px"
        case .custom: return "Any size"
        default:
            guard let size else { return "" }
            return "\(Int(size.width)) × \(Int(size.height))"
        }
    }
}

struct ResizedImageResult: Identifiable {
    let id = UUID()
    let fileURL: URL
    let filename: String
    let originalPixels: CGSize
    let newPixels: CGSize
    let originalBytes: Int
    let newBytes: Int
}

extension CGSize {
    var pixelDescription: String { "\(Int(width)) × \(Int(height))" }
}

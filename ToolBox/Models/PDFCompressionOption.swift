import Foundation

/// Quality-based presets — trade visual fidelity for file size by
/// controlling both the JPEG quality used per page and the maximum
/// pixel dimension pages are rendered at.
enum CompressionQuality: String, CaseIterable, Identifiable {
    case maximumQuality = "Maximum Quality"
    case balanced = "Balanced"
    case smallestFile = "Smallest File"

    var id: String { rawValue }

    /// (JPEG quality 0...1, max long-edge pixels)
    var settings: (jpegQuality: CGFloat, maxDimension: CGFloat) {
        switch self {
        case .maximumQuality: return (0.9, 2200)
        case .balanced: return (0.6, 1600)
        case .smallestFile: return (0.35, 1100)
        }
    }
}

/// Explicit target file sizes — the compressor searches for settings
/// that land under the target rather than using a fixed preset.
enum TargetSize: Hashable, Identifiable {
    case under500KB
    case under1MB
    case under2MB
    case under5MB
    case custom(Int)

    var id: Int { bytes }

    var label: String {
        switch self {
        case .under500KB: return "Under 500 KB"
        case .under1MB: return "Under 1 MB"
        case .under2MB: return "Under 2 MB"
        case .under5MB: return "Under 5 MB"
        case .custom: return "Custom"
        }
    }

    var bytes: Int {
        switch self {
        case .under500KB: return 500_000
        case .under1MB: return 1_000_000
        case .under2MB: return 2_000_000
        case .under5MB: return 5_000_000
        case .custom(let value): return value
        }
    }

    static let presets: [TargetSize] = [.under500KB, .under1MB, .under2MB, .under5MB]
}

enum CompressionMode: Hashable {
    case quality(CompressionQuality)
    case targetSize(TargetSize)
}

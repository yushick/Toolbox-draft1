import UIKit

/// Enhancement mode applied to a scanned page — matches the spec's
/// Color / Grayscale / B&W options.
enum PageEnhancement: String, CaseIterable, Identifiable {
    case color = "Color"
    case grayscale = "Grayscale"
    case blackAndWhite = "B&W"

    var id: String { rawValue }
}

/// One page in an in-progress scan. Kept in memory only until the
/// user creates the PDF — nothing is written to disk per page.
struct ScannedPage: Identifiable, Equatable {
    let id: UUID
    /// The original, unedited capture — enhancement is applied for
    /// preview/export but never destroys the source pixel data in
    /// memory, so switching enhancement modes stays non-destructive.
    let originalImage: UIImage

    init(id: UUID = UUID(), originalImage: UIImage) {
        self.id = id
        self.originalImage = originalImage
    }

    static func == (lhs: ScannedPage, rhs: ScannedPage) -> Bool { lhs.id == rhs.id }
}

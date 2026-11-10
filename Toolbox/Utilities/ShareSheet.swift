import UIKit

/// Presents the native iOS share sheet (which includes Save to Files).
enum ShareSheet {
    @MainActor
    static func present(_ urls: [URL]) {
        let controller = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        var top = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        top?.present(controller, animated: true)
    }
}

extension Int {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file)
    }
}

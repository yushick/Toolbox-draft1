import Foundation
import Photos

/// Writes generated files into the app's Documents folder, adding
/// " (2)", " (3)"… instead of overwriting an existing file.
enum OutputFiles {
    static func write(_ data: Data, name: String, ext: String) throws -> URL {
        let directory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                    appropriateFor: nil, create: true)
        var candidate = directory.appendingPathComponent("\(name).\(ext)")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(name) (\(counter)).\(ext)")
            counter += 1
        }
        try data.write(to: candidate, options: .atomic)
        return candidate
    }
}

enum PhotoLibrarySaver {
    enum Outcome { case saved(Int), denied, failed }

    /// Add-only access, requested only when the user taps Save.
    static func save(_ urls: [URL]) async -> Outcome {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return .denied }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for url in urls { PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: url) }
            }
            return .saved(urls.count)
        } catch {
            return .failed
        }
    }
}

import Foundation
import SwiftData

enum ProcessedFileKind: String, Codable {
    case pdf
    case image
    case text
}

/// Metadata for a file the app generated. The binary itself lives in
/// the app sandbox (Application Support / Documents); only the
/// reference and metadata are stored in SwiftData.
@Model
final class ProcessedFile {
    var id: UUID
    var filename: String
    var kind: String            // ProcessedFileKind.rawValue
    var byteSize: Int
    var createdAt: Date
    /// Path relative to the app's sandbox container, not an absolute
    /// path — sandboxes can be re-provisioned between launches.
    var relativePath: String

    init(filename: String, kind: ProcessedFileKind, byteSize: Int,
         relativePath: String, createdAt: Date = .now) {
        self.id = UUID()
        self.filename = filename
        self.kind = kind.rawValue
        self.byteSize = byteSize
        self.relativePath = relativePath
        self.createdAt = createdAt
    }
}

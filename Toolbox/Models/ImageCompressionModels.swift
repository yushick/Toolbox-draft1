import Foundation
import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// A photo chosen in the picker, already copied to a temp file so the
/// full-resolution original is never held in memory.
struct PickedImage: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let originalBytes: Int
    let thumbnail: UIImage?
}

struct CompressedImageResult: Identifiable {
    let id = UUID()
    let fileURL: URL
    let filename: String
    let originalBytes: Int
    let compressedBytes: Int

    var savedBytes: Int { max(0, originalBytes - compressedBytes) }
}

/// File-backed transfer from PhotosPicker: copies the asset to a temp
/// file rather than loading it into `Data`.
struct PickedImageFile: Transferable {
    let url: URL
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("picked", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let base = received.file.deletingPathExtension().lastPathComponent
            let destination = directory.appendingPathComponent("\(UUID().uuidString)-\(received.file.lastPathComponent)")
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedImageFile(url: destination, name: base)
        }
    }
}

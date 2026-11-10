import Foundation

/// File operations on the documents Toolbox has created. Files live in the
/// app's Documents folder and are found by the relative name stored in
/// SwiftData, so they survive the app container being moved.
enum FileService {

    enum FileError: LocalizedError {
        case emptyName
        case nameTaken
        case missing
        case failed

        var errorDescription: String? {
            switch self {
            case .emptyName: return "Please enter a name."
            case .nameTaken: return "A file with that name already exists. Try a different name."
            case .missing: return "This file is no longer in Toolbox's storage."
            case .failed: return "Something went wrong. Please try again."
            }
        }
    }

    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func url(for file: ProcessedFile) -> URL {
        documentsDirectory.appendingPathComponent(file.relativePath)
    }

    static func exists(_ file: ProcessedFile) -> Bool {
        FileManager.default.fileExists(atPath: url(for: file).path)
    }

    /// Name without extension, ready for the rename field.
    static func baseName(of file: ProcessedFile) -> String {
        (file.filename as NSString).deletingPathExtension
    }

    static func fileExtension(of file: ProcessedFile) -> String {
        (file.filename as NSString).pathExtension
    }

    /// Removes characters that aren't allowed in file names. Returns nil
    /// if nothing usable is left.
    static func sanitizedBaseName(_ name: String) -> String? {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
        var cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: invalid).joined(separator: "-")
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        cleaned = String(cleaned.prefix(100)).trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? nil : cleaned
    }

    /// Renames the file on disk and updates the record. The extension is kept.
    static func rename(_ file: ProcessedFile, to newName: String) throws {
        guard var base = sanitizedBaseName(newName) else { throw FileError.emptyName }
        let ext = fileExtension(of: file)

        // If the user typed the extension too, don't double it.
        if !ext.isEmpty, base.lowercased().hasSuffix("." + ext.lowercased()) {
            base = String(base.dropLast(ext.count + 1))
            if base.isEmpty { throw FileError.emptyName }
        }

        let newFilename = ext.isEmpty ? base : "\(base).\(ext)"
        if newFilename == file.filename { return }

        let source = url(for: file)
        guard FileManager.default.fileExists(atPath: source.path) else { throw FileError.missing }

        let destination = documentsDirectory.appendingPathComponent(newFilename)
        let onlyCaseChanged = newFilename.lowercased() == file.filename.lowercased()
        if FileManager.default.fileExists(atPath: destination.path), !onlyCaseChanged {
            throw FileError.nameTaken
        }

        do {
            try FileManager.default.moveItem(at: source, to: destination)
        } catch {
            throw FileError.failed
        }
        file.filename = newFilename
        file.relativePath = newFilename
    }

    /// Deletes the file from disk. A file that's already gone is fine.
    static func deleteFromDisk(_ file: ProcessedFile) throws {
        let target = url(for: file)
        guard FileManager.default.fileExists(atPath: target.path) else { return }
        do {
            try FileManager.default.removeItem(at: target)
        } catch {
            throw FileError.failed
        }
    }
}

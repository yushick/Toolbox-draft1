import Foundation
import SwiftUI
import SwiftData
import UIKit
import Observation

enum FileSort: String, CaseIterable, Identifiable {
    case newest = "Newest First"
    case oldest = "Oldest First"
    case name = "Name"
    case size = "Largest First"

    var id: String { rawValue }
    var groupsByDay: Bool { self == .newest || self == .oldest }
}

struct FileSection: Identifiable {
    let id: String
    let title: String?
    let files: [ProcessedFile]
}

@MainActor
@Observable
final class FilesViewModel {
    var searchText = ""

    var previewURL: URL?
    var fileToDelete: ProcessedFile?
    var fileToRename: ProcessedFile?
    var renameText = ""
    var alertMessage: String?

    // MARK: - Filtering, sorting, grouping

    func visibleFiles(from files: [ProcessedFile], sort: FileSort) -> [ProcessedFile] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = query.isEmpty
            ? files
            : files.filter { $0.filename.localizedCaseInsensitiveContains(query) }

        switch sort {
        case .newest: return filtered.sorted { $0.createdAt > $1.createdAt }
        case .oldest: return filtered.sorted { $0.createdAt < $1.createdAt }
        case .name: return filtered.sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        case .size: return filtered.sorted { $0.byteSize > $1.byteSize }
        }
    }

    func sections(from files: [ProcessedFile], sort: FileSort) -> [FileSection] {
        let sorted = visibleFiles(from: files, sort: sort)
        guard !sorted.isEmpty else { return [] }
        guard sort.groupsByDay else { return [FileSection(id: "all", title: nil, files: sorted)] }

        let calendar = Calendar.current
        var sections: [FileSection] = []
        var currentDay: Date?
        var bucket: [ProcessedFile] = []

        func flush() {
            guard let day = currentDay, !bucket.isEmpty else { return }
            sections.append(FileSection(id: "\(day.timeIntervalSince1970)",
                                        title: Self.dayTitle(for: day), files: bucket))
            bucket = []
        }

        for file in sorted {
            let day = calendar.startOfDay(for: file.createdAt)
            if day != currentDay { flush(); currentDay = day }
            bucket.append(file)
        }
        flush()
        return sections
    }

    static func dayTitle(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }

    func totalSizeDescription(of files: [ProcessedFile]) -> String {
        let bytes = files.reduce(0) { $0 + $1.byteSize }
        let count = files.count
        return "\(count) file\(count == 1 ? "" : "s") · \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))"
    }

    // MARK: - Actions

    func preview(_ file: ProcessedFile) {
        guard FileService.exists(file) else { alertMessage = FileService.FileError.missing.localizedDescription; return }
        previewURL = FileService.url(for: file)
    }

    func share(_ file: ProcessedFile) {
        guard FileService.exists(file) else { alertMessage = FileService.FileError.missing.localizedDescription; return }
        ShareSheet.present([FileService.url(for: file)])
    }

    /// Opens the Files app at this file's location. Needs file sharing
    /// enabled (the two Info keys from Stage 3); otherwise falls back to the share sheet.
    func openInFiles(_ file: ProcessedFile) {
        guard FileService.exists(file) else { alertMessage = FileService.FileError.missing.localizedDescription; return }
        let url = FileService.url(for: file)
        let filesURL = URL(string: url.absoluteString.replacingOccurrences(of: "file://", with: "shareddocuments://"))
        guard let filesURL else { ShareSheet.present([url]); return }
        UIApplication.shared.open(filesURL) { opened in
            if !opened { Task { @MainActor in ShareSheet.present([url]) } }
        }
    }

    func beginRename(_ file: ProcessedFile) {
        renameText = FileService.baseName(of: file)
        fileToRename = file
    }

    func commitRename() {
        guard let file = fileToRename else { return }
        fileToRename = nil
        do {
            try FileService.rename(file, to: renameText)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func delete(_ file: ProcessedFile, in context: ModelContext) {
        fileToDelete = nil
        do {
            try FileService.deleteFromDisk(file)
            context.delete(file)
            try? context.save()
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
